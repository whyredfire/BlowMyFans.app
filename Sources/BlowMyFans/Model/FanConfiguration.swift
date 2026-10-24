import HelperInterface
import SMCKit

struct ManualSettings: Codable, Equatable {
    /// One speed for every fan.
    var rpm: Double = 4000
}

extension ManualSettings {
    private enum CodingKeys: String, CodingKey {
        case rpm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rpm = container.value(for: .rpm, default: ManualSettings().rpm)
        self.rpm = rpm.isFinite && rpm >= 0 ? rpm : ManualSettings().rpm
    }
}

struct FanConfiguration: Codable, Equatable {
    var mode = FanMode.automatic
    var manual = ManualSettings()
    var curve = FanCurve()

    /// Speeds to request per fan (in hardware order), or nil to leave fans to macOS.
    ///
    /// `FanSpeedRequest.off` stops the fans: in Manual mode below the slider's minimum, and in Curve
    /// mode where the curve is at 0%. Fans must have a usable speed range.
    /// - Parameter sliderMinimum: Lower bound of the speed slider; a manual speed below it means
    ///   "off". Above it, each fan is clamped to its own range.
    func targetRPMs(
        for fans: [Fan], cpuTemperature: Double?, sliderMinimum: Double?
    ) -> [Double]? {
        switch mode {
        case .automatic:
            return nil
        case .fullBlast:
            return fans.map(\.maximumRPM)
        case .manual:
            let offThreshold = sliderMinimum ?? fans.map(\.minimumRPM).min() ?? 0
            return fans.map { fan in
                if manual.rpm < offThreshold { return FanSpeedRequest.off }
                return min(max(manual.rpm, fan.minimumRPM), fan.maximumRPM)
            }
        case .curve:
            // Run flat out if no CPU temperature is available.
            let fraction = cpuTemperature.map(curve.speed) ?? 1
            return fans.map { fan in
                if fraction == 0 { return FanSpeedRequest.off }
                let rpm = fan.minimumRPM + fraction * (fan.maximumRPM - fan.minimumRPM)
                return min(max((rpm / 50).rounded() * 50, fan.minimumRPM), fan.maximumRPM)
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
