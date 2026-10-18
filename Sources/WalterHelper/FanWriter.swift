import Foundation
import HelperInterface
import SMCKit

struct FanWriter: Sendable {
    let smc: SMC

    /// SMC result code returned while thermalmonitord still owns the fans.
    private static let busyResult: UInt8 = 0x82
    /// How long a hand-back waits before falling back to full speed; the session retries it later.
    private static let releaseTimeout = Duration.seconds(5)

    /// `rpms` holds one speed per fan; see `FanHelperProtocol.setFanSpeeds` for the encoding.
    /// Returns false if macOS hadn't released the fans within `timeout`; they stay under its control
    /// and calling again keeps trying. Measured on M4, the release takes ~5 s from a settled state
    /// and until ~15 s after macOS last took the fans back.
    /// `shouldAbort` is polled while waiting on the SMC; returning true throws `FanWriterError.interrupted`.
    @discardableResult
    func setSpeeds(_ rpms: [Double], waitingUpTo timeout: Duration, shouldAbort: () -> Bool = { false }) throws -> Bool {
        let fans = smc.fans()
        guard !fans.isEmpty else { throw HelperError("No fans found") }
        guard rpms.count == fans.count else { throw HelperError("Expected \(fans.count) fan speeds") }
        // Resolve everything before touching the SMC so a bad reading never half-applies.
        let targets = try zip(fans, rpms).map { fan, rpm in try Self.target(for: rpm, fan: fan) }

        try unlock()
        let deadline = ContinuousClock.now + timeout
        for (fan, target) in zip(fans, targets) {
            guard try writeMode(.manual, fan: fan.id, until: deadline, shouldAbort: shouldAbort) else { return false }
            // Set the target straight away: a manual fan otherwise keeps the system's last
            // target, which is 0 when macOS had the fans stopped.
            try smc.write(FanKey.target(fan.id), value: target)
        }
        return true
    }

    /// Hands fans in manual mode back to macOS. Any fan the SMC won't release yet is run at
    /// full speed and the error is rethrown so the caller can retry.
    func restoreAutomatic() throws {
        let manualFans = smc.fans().filter(\.isManual)
        if !manualFans.isEmpty {
            try unlock()
            let deadline = ContinuousClock.now + Self.releaseTimeout
            var failure: Error?
            for fan in manualFans where (try? writeMode(.automatic, fan: fan.id, until: deadline)) != true {
                failure = failure ?? FanWriterError.releaseRefused
                if fan.hasUsableSpeedRange { try? smc.write(FanKey.target(fan.id), value: fan.maximumRPM) }
            }
            if let failure { throw failure }
        }
        if smc.contains(FanKey.unlock) {
            try smc.write(FanKey.unlock, value: 0)
        }
    }

    var isManualActive: Bool {
        smc.readDouble(FanKey.unlock) == 1 || smc.fans().contains(where: \.isManual)
    }

    /// True when the fans have drifted from `rpms`, e.g. because the system took control back.
    /// False when the fans can't be read reliably, so a flaky read never triggers a rewrite.
    func needsReapply(_ rpms: [Double]) -> Bool {
        let fans = smc.fans()
        guard fans.count == rpms.count,
              let targets = try? zip(fans, rpms).map({ fan, rpm in try Self.target(for: rpm, fan: fan) })
        else { return false }
        if smc.contains(FanKey.unlock), smc.readDouble(FanKey.unlock) != 1 { return true }
        return !zip(fans, targets).allSatisfy { fan, target in
            fan.isManual && abs(fan.targetRPM - target) < 1
        }
    }

    /// The value written to `F{n}Tg` for a requested speed.
    private static func target(for rpm: Double, fan: Fan) throws -> Double {
        guard fan.hasUsableSpeedRange else {
            throw HelperError("Couldn't read the speed range of fan \(fan.id + 1)")
        }
        if rpm == FanSpeedRequest.off { return 0 }
        guard rpm.isFinite else { return fan.minimumRPM }
        return min(max(rpm, fan.minimumRPM), fan.maximumRPM)
    }

    private func unlock() throws {
        if smc.contains(FanKey.unlock), smc.readDouble(FanKey.unlock) != 1 {
            try smc.write(FanKey.unlock, value: 1)
        }
    }

    /// After unlocking, the SMC rejects mode writes (0x82) until thermalmonitord releases the
    /// fans; how long that takes depends on its state. Returns false if it's still busy at
    /// `deadline`, after at least one attempt. Any other error is final.
    private func writeMode(
        _ mode: FanControlMode, fan: Int, until deadline: ContinuousClock.Instant, shouldAbort: () -> Bool = { false }
    ) throws -> Bool {
        while true {
            if shouldAbort() { throw FanWriterError.interrupted }
            do {
                try smc.write(smc.modeKey(fan), value: Double(mode.rawValue))
                return true
            } catch SMCError.smc(key: _, code: Self.busyResult) {
                guard ContinuousClock.now < deadline else { return false }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
}

enum FanWriterError: LocalizedError {
    /// A write was abandoned because the system is going to sleep or the helper is exiting.
    case interrupted
    /// macOS didn't take the fans back yet; they run at full speed until it does.
    case releaseRefused

    var errorDescription: String? {
        switch self {
        case .interrupted: "Fan control was interrupted by sleep or shutdown."
        case .releaseRefused: "macOS hasn't taken the fans back yet, so they're running at full speed until it does."
        }
    }
}

struct HelperError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
