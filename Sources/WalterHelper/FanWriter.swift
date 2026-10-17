import Foundation
import HelperInterface
import SMCKit

struct FanWriter: Sendable {
    let smc: SMC

    /// SMC result code returned while thermalmonitord still owns the fans.
    private static let busyResult: UInt8 = 0x82
    /// Longest wait for the SMC to accept manual mode, across all fans. Measured on M4:
    /// ~5 s from a settled state, ~11 s if macOS took the fans back a few seconds earlier.
    private static let takeoverTimeout = Duration.seconds(30)

    /// `rpms` holds one speed per fan; see `FanHelperProtocol.setFanSpeeds` for the encoding.
    /// `shouldAbort` is polled while waiting on the SMC; returning true throws `FanWriterError.interrupted`.
    func setSpeeds(_ rpms: [Double], shouldAbort: () -> Bool = { false }) throws {
        let fans = smc.fans()
        guard !fans.isEmpty else { throw HelperError("No fans found") }
        guard rpms.count == fans.count else { throw HelperError("Expected \(fans.count) fan speeds") }
        // Resolve everything before touching the SMC so a bad reading never half-applies.
        let targets = try zip(fans, rpms).map { fan, rpm in try Self.target(for: rpm, fan: fan) }

        try takeManualControl(of: fans, shouldAbort: shouldAbort)
        for (fan, target) in zip(fans, targets) {
            try smc.write(FanKey.target(fan.id), value: target)
        }
    }

    func restoreAutomatic() throws {
        var firstError: Error?
        for fan in 0..<smc.fanCount {
            do { try smc.write(smc.modeKey(fan), value: Double(FanControlMode.automatic.rawValue)) }
            catch { firstError = firstError ?? error }
        }
        if smc.contains(FanKey.unlock) {
            try smc.write(FanKey.unlock, value: 0)
        }
        if let firstError { throw firstError }
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

    private func takeManualControl(of fans: [Fan], shouldAbort: () -> Bool) throws {
        if smc.contains(FanKey.unlock), smc.readDouble(FanKey.unlock) != 1 {
            try smc.write(FanKey.unlock, value: 1)
        }
        let deadline = ContinuousClock.now + Self.takeoverTimeout
        for fan in fans {
            // After unlocking, the SMC rejects mode writes (0x82) until thermalmonitord
            // releases control. Any other error is final.
            while true {
                if shouldAbort() { throw FanWriterError.interrupted }
                do {
                    try smc.write(smc.modeKey(fan.id), value: Double(FanControlMode.manual.rawValue))
                    break
                } catch SMCError.smc(key: _, code: Self.busyResult) {
                    guard ContinuousClock.now < deadline else { throw FanWriterError.systemBusy }
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
    }
}

enum FanWriterError: LocalizedError {
    /// A write was abandoned because the system is going to sleep or the helper is exiting.
    case interrupted
    /// macOS didn't hand over the fans before the takeover timeout.
    case systemBusy

    var errorDescription: String? {
        switch self {
        case .interrupted: "Fan control was interrupted by sleep or shutdown."
        case .systemBusy: "macOS is still managing the fans. Try again in a few seconds."
        }
    }
}

struct HelperError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
