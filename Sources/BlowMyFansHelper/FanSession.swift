import Foundation
import HelperInterface
import Synchronization

/// Serialises fan writes and remembers which client owns manual control,
/// so fans return to automatic when that client disconnects.
///
/// Any failure while applying speeds hands the fans back to macOS. If macOS refuses to take
/// them back, they run at full speed and the hand-back is retried until it succeeds.
///
/// The helper can't be sure its client is the app, or that the app is still working, so two limits
/// hold whatever a client asks for: an owner that goes quiet loses the fans to macOS, and an
/// overheating Mac gets full speed.
final class FanSession: Sendable {
    typealias ClientID = ObjectIdentifier

    private struct State {
        var owner: ClientID?
        var targetRPMs: [Double]?
        /// A hand-back macOS refused; `maintain()` retries it.
        var releasePending = false
        /// When the owner last set speeds or sent a keep-alive.
        var lastHeard = ContinuousClock.now
        /// While set, the Mac is too hot and the fans run at full speed instead of `targetRPMs`.
        var coolingUntil: ContinuousClock.Instant?
    }

    private static let takeoverWait = Duration.seconds(10)

    /// An owner silent for this long has hung, so its speeds no longer follow anything.
    private let clientTimeout: Duration
    /// How long the fans stay at full speed after the Mac was last too hot, so they don't flick
    /// between full speed and a speed that lets it overheat again.
    private let cooldown: Duration
    private let isOverheating: @Sendable () -> Bool
    private let writer: FanWriter
    private let state = Mutex(State())
    /// Checked without the lock so a write blocked on the SMC gives up promptly.
    private let isSleeping = Atomic(false)
    private let isTerminating = Atomic(false)
    /// Told whenever `maintain()` gains or runs out of work, so it's only scheduled while needed.
    private let onMaintenanceNeeded: @Sendable (Bool) -> Void
    private let isMaintenanceNeeded = Atomic(false)

    /// - Parameter isOverheating: By default, whether macOS reports serious or critical thermal
    ///   pressure, the point at which it would run the fans flat out itself.
    init(
        writer: FanWriter,
        clientTimeout: Duration = .seconds(30),
        cooldown: Duration = .seconds(60),
        isOverheating: @escaping @Sendable () -> Bool = {
            ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
        },
        onMaintenanceNeeded: @escaping @Sendable (Bool) -> Void
    ) {
        self.writer = writer
        self.clientTimeout = clientTimeout
        self.cooldown = cooldown
        self.isOverheating = isOverheating
        self.onMaintenanceNeeded = onMaintenanceNeeded
    }

    private var shouldAbort: Bool {
        isSleeping.load(ordering: .sequentiallyConsistent) || isTerminating.load(ordering: .sequentiallyConsistent)
    }

    func setSpeeds(_ rpms: [Double], for client: ClientID) throws {
        try update { state in
            state = State(owner: client, targetRPMs: rpms, coolingUntil: state.coolingUntil)
            // macOS keeps the fans while asleep; the request is applied on wake.
            guard !shouldAbort else { return }
            do {
                try writer.setSpeeds(speeds(for: rpms, &state), waitingUpTo: Self.takeoverWait) { self.shouldAbort }
            } catch FanWriterError.interrupted where !isTerminating.load(ordering: .sequentiallyConsistent) {
                // Sleep started mid-write: systemWillSleep restores automatic, and wake re-applies.
            } catch {
                release(&state)
                throw error
            }
        }
    }

    func restoreAutomatic() throws {
        try update { state in
            state = State()
            do {
                try writer.restoreAutomatic()
            } catch {
                state.releasePending = true
                throw error
            }
        }
    }

    /// Notes that `client` is still running and reports what the helper is doing for it.
    func keepAlive(for client: ClientID) -> FanHelperState {
        state.withLock { state in
            guard state.owner == client, state.targetRPMs != nil else { return .released }
            state.lastHeard = .now
            return state.coolingUntil == nil ? .applied : .cooling
        }
    }

    /// Hands back fans left in manual mode by a previous helper instance.
    func releaseStaleControl() {
        update { state in
            guard state.owner == nil, writer.isManualActive else { return }
            release(&state)
        }
    }

    /// Runs every few seconds: completes pending takeovers, re-applies requested speeds the system
    /// took back, retries hand-backs macOS refused, drops an owner that has gone quiet and switches
    /// to full speed and back as the Mac overheats and cools down.
    func maintain() {
        update { state in
            guard !shouldAbort else { return }
            if state.releasePending {
                release(&state)
                return
            }
            guard let requested = state.targetRPMs else { return }
            if ContinuousClock.now - state.lastHeard > clientTimeout {
                NSLog("The app stopped responding, returning fans to macOS")
                release(&state)
                return
            }
            let rpms = speeds(for: requested, &state)
            guard writer.needsReapply(rpms) else { return }
            do {
                try writer.setSpeeds(rpms, waitingUpTo: .zero) { self.shouldAbort }
            } catch FanWriterError.interrupted {
                // The sleep or termination handler restores automatic control.
            } catch {
                NSLog("Unable to re-apply fan speed, returning fans to macOS: %@", error.localizedDescription)
                release(&state)
            }
        }
    }

    func clientDisconnected(_ client: ClientID) {
        update { state in
            guard state.owner == client else { return }
            release(&state)
        }
    }

    // MARK: System power

    /// Lets macOS manage the fans while asleep. The owner and targets are kept for wake.
    func systemWillSleep() {
        isSleeping.store(true, ordering: .sequentiallyConsistent)
        update { state in
            guard state.targetRPMs != nil || state.releasePending || writer.isManualActive else { return }
            do {
                try writer.restoreAutomatic()
            } catch {
                state.releasePending = true
                NSLog("Unable to restore automatic fan control before sleep: %@", error.localizedDescription)
            }
        }
    }

    /// Re-enables writes; call `maintain()` afterwards to re-apply the stored targets.
    func systemDidWake() {
        // The owner was asleep as well; its silence counts from now.
        state.withLock { $0.lastHeard = .now }
        isSleeping.store(false, ordering: .sequentiallyConsistent)
    }

    /// Abandons any in-flight write and hands the fans back to macOS before the helper exits.
    func prepareForExit() {
        isTerminating.store(true, ordering: .sequentiallyConsistent)
        do {
            try restoreAutomatic()
        } catch {
            NSLog("Unable to restore automatic fan control on exit: %@", error.localizedDescription)
        }
    }

    /// Changes the state under the lock, then reports whether `maintain()` has work.
    private func update<E: Error>(_ body: (inout State) throws(E) -> Void) throws(E) {
        try state.withLock { state throws(E) in
            defer {
                let needed = state.targetRPMs != nil || state.releasePending
                if isMaintenanceNeeded.exchange(needed, ordering: .sequentiallyConsistent) != needed {
                    onMaintenanceNeeded(needed)
                }
            }
            try body(&state)
        }
    }

    /// The speeds to write for a request: full speed while the Mac is too hot and for `cooldown`
    /// afterwards, whatever was asked for, so a slow or stopped fan never keeps it hot.
    private func speeds(for rpms: [Double], _ state: inout State) -> [Double] {
        let now = ContinuousClock.now
        if isOverheating() {
            state.coolingUntil = now + cooldown
        } else if let until = state.coolingUntil, now >= until {
            state.coolingUntil = nil
        }
        return state.coolingUntil == nil ? rpms : rpms.map { _ in FanSpeedRequest.full }
    }

    /// Forgets the request and hands the fans back, remembering a refusal for `maintain()`.
    private func release(_ state: inout State) {
        state = State()
        do {
            try writer.restoreAutomatic()
        } catch {
            state.releasePending = true
            NSLog("macOS hasn't taken the fans back yet: %@", error.localizedDescription)
        }
    }
}
