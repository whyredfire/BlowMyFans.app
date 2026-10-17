import HelperInterface
import SMCKit

struct ManualSettings: Codable, Equatable {
    var linked = true
    var rpm: Double = 4000
    var fanRPMs: [Int: Double] = [:]

    func rpm(forFan fan: Int) -> Double {
        linked ? rpm : fanRPMs[fan] ?? rpm
    }
}

extension ManualSettings {
    private enum CodingKeys: String, CodingKey {
        case linked, rpm, fanRPMs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ManualSettings()
        linked = container.value(for: .linked, default: defaults.linked)
        let rpm = container.value(for: .rpm, default: defaults.rpm)
        self.rpm = rpm.isFinite && rpm >= 0 ? rpm : defaults.rpm
        fanRPMs = container.value(for: .fanRPMs, default: defaults.fanRPMs).filter { $0.value.isFinite && $0.value >= 0 }
    }
}

struct FanConfiguration: Codable, Equatable {
    var mode = FanMode.automatic
    var manual = ManualSettings()
    var curve = FanCurve()

    /// Speeds to request per fan (in hardware order), or nil to leave fans to macOS.
    ///
    /// Only Manual mode with `allowFanOff` ever requests `FanSpeedRequest.off`. Fans must have
    /// a usable speed range.
    /// - Parameters:
    ///   - linkFans: Every fan follows the single linked speed (synchronised or single-fan Macs).
    ///   - linkedMinimum: Lower bound of the linked speed slider; a linked speed below it means
    ///     "off". Above it, each fan is clamped to its own minimum.
    func targetRPMs(
        for fans: [Fan], temperatures: [SensorGroupReading], linkFans: Bool, allowFanOff: Bool, linkedMinimum: Double?
    ) -> [Double]? {
        switch mode {
        case .automatic:
            return nil
        case .fullBlast:
            return fans.map(\.maximumRPM)
        case .manual:
            let linked = linkFans || manual.linked
            let linkedOffThreshold = linkedMinimum ?? fans.map(\.minimumRPM).min() ?? 0
            return fans.map { fan in
                let rpm = linked ? manual.rpm : manual.rpm(forFan: fan.id)
                let offThreshold = linked ? linkedOffThreshold : fan.minimumRPM
                if allowFanOff, rpm < offThreshold { return FanSpeedRequest.off }
                return min(max(rpm, fan.minimumRPM), fan.maximumRPM)
            }
        case .curve:
            // Run flat out if no CPU temperature is available.
            let fraction = temperatures.hottestCPU.map(curve.speed) ?? 1
            return fans.map { fan in
                let rpm = fan.minimumRPM + fraction * (fan.maximumRPM - fan.minimumRPM)
                return (rpm / 50).rounded() * 50
            }
        }
    }
}

extension FanConfiguration {
    private enum CodingKeys: String, CodingKey {
        case mode, manual, curve
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FanConfiguration()
        mode = container.value(for: .mode, default: defaults.mode)
        manual = container.value(for: .manual, default: defaults.manual)
        curve = container.value(for: .curve, default: defaults.curve)
    }
}
