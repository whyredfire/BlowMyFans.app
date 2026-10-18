import Foundation
import Synchronization

/// Serialises fan writes and remembers which client owns manual control,
/// so fans return to automatic when that client disconnects.
///
/// Any failure while applying speeds hands the fans back to macOS. If macOS refuses to take
/// them back, they run at full speed and the hand-back is retried until it succeeds.
final class FanSession: Sendable {
    typealias ClientID = ObjectIdentifier

    private struct State {
        var owner: ClientID?
        var targetRPMs: [Double]?
        /// A hand-back macOS refused; `maintain()` retries it.
        var releasePending = false
    }

    private static let takeoverWait = Duration.seconds(10)

    private let writer: FanWriter
    private let state = Mutex(State())
    /// Checked without the lock so a write blocked on the SMC gives up promptly.
    private let isSleeping = Atomic(false)
    private let isTerminating = Atomic(false)
    /// Told whenever `maintain()` gains or runs out of work, so it's only scheduled while needed.
    private let onMaintenanceNeeded: @Sendable (Bool) -> Void
    private let isMaintenanceNeeded = Atomic(false)

    init(writer: FanWriter, onMaintenanceNeeded: @escaping @Sendable (Bool) -> Void) {
        self.writer = writer
        self.onMaintenanceNeeded = onMaintenanceNeeded
    }

    private var shouldAbort: Bool {
        isSleeping.load(ordering: .sequentiallyConsistent) || isTerminating.load(ordering: .sequentiallyConsistent)
    }

    func setSpeeds(_ rpms: [Double], for client: ClientID) throws {
        try update { state in
            state = State(owner: client, targetRPMs: rpms)
            // macOS keeps the fans while asleep; the request is applied on wake.
            guard !shouldAbort else { return }
            do {
                try writer.setSpeeds(rpms, waitingUpTo: Self.takeoverWait) { self.shouldAbort }
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

    /// Hands back fans left in manual mode by a previous helper instance.
    func releaseStaleControl() {
        update { state in
            guard state.owner == nil, writer.isManualActive else { return }
            release(&state)
        }
    }

    /// Runs every few seconds: completes pending takeovers, re-applies requested speeds the system
    /// took back, and retries hand-backs macOS refused.
    func maintain() {
        update { state in
            guard !shouldAbort else { return }
            if state.releasePending {
                release(&state)
                return
            }
            guard let rpms = state.targetRPMs, writer.needsReapply(rpms) else { return }
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
