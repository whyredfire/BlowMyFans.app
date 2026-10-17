import Foundation
import Synchronization

/// Serialises fan writes and remembers which client owns manual control,
/// so fans return to automatic when that client disconnects.
///
/// Any failure while applying speeds hands the fans back to macOS and forgets the
/// request, so fans are never left half-configured.
final class FanSession: Sendable {
    typealias ClientID = ObjectIdentifier

    private struct State {
        var owner: ClientID?
        var targetRPMs: [Double]?
    }

    private let writer: FanWriter
    private let state = Mutex(State())
    /// Checked without the lock so a write blocked on the SMC gives up promptly.
    private let isSleeping = Atomic(false)
    private let isTerminating = Atomic(false)

    init(writer: FanWriter) {
        self.writer = writer
    }

    private var shouldAbort: Bool {
        isSleeping.load(ordering: .sequentiallyConsistent) || isTerminating.load(ordering: .sequentiallyConsistent)
    }

    func setSpeeds(_ rpms: [Double], for client: ClientID) throws {
        try state.withLock { state in
            state = State(owner: client, targetRPMs: rpms)
            // macOS keeps the fans while asleep; the request is applied on wake.
            guard !shouldAbort else { return }
            do {
                try writer.setSpeeds(rpms) { self.shouldAbort }
            } catch FanWriterError.interrupted where !isTerminating.load(ordering: .sequentiallyConsistent) {
                // Sleep started mid-write: systemWillSleep restores automatic, and wake re-applies.
            } catch {
                state = State()
                try? writer.restoreAutomatic()
                throw error
            }
        }
    }

    func restoreAutomatic() throws {
        try state.withLock { state in
            state = State()
            try writer.restoreAutomatic()
        }
    }

    /// Hands back fans left in manual mode by a previous helper instance.
    func releaseStaleControl() {
        state.withLock { state in
            guard state.owner == nil, writer.isManualActive else { return }
            try? writer.restoreAutomatic()
        }
    }

    func reassertIfNeeded() {
        state.withLock { state in
            guard !shouldAbort, let rpms = state.targetRPMs, writer.needsReapply(rpms) else { return }
            do {
                try writer.setSpeeds(rpms) { self.shouldAbort }
            } catch FanWriterError.interrupted {
                // The sleep or termination handler restores automatic control.
            } catch {
                NSLog("Unable to re-apply fan speed, returning fans to macOS: %@", error.localizedDescription)
                state = State()
                try? writer.restoreAutomatic()
            }
        }
    }

    func clientDisconnected(_ client: ClientID) {
        state.withLock { state in
            guard state.owner == client else { return }
            state = State()
            try? writer.restoreAutomatic()
        }
    }

    // MARK: System power

    /// Lets macOS manage the fans while asleep. The owner and targets are kept for wake.
    func systemWillSleep() {
        isSleeping.store(true, ordering: .sequentiallyConsistent)
        state.withLock { state in
            guard state.targetRPMs != nil || writer.isManualActive else { return }
            do {
                try writer.restoreAutomatic()
            } catch {
                NSLog("Unable to restore automatic fan control before sleep: %@", error.localizedDescription)
            }
        }
    }

    /// Re-enables writes; call `reassertIfNeeded()` afterwards to re-apply the stored targets.
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
}
