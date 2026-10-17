public struct Fan: Identifiable, Sendable, Equatable {
    public let id: Int
    public var name: String
    public var currentRPM: Double
    public var minimumRPM: Double
    public var maximumRPM: Double
    public var targetRPM: Double
    public var isManual: Bool

    public var speedRange: ClosedRange<Double> { minimumRPM...max(minimumRPM, maximumRPM) }

    /// False when the SMC reported unusable limits, e.g. 0 RPM after a failed read.
    public var hasUsableSpeedRange: Bool {
        minimumRPM.isFinite && maximumRPM.isFinite && minimumRPM >= 0 && maximumRPM > minimumRPM
    }
}

public enum FanKey {
    public static let count = "FNum"
    /// Present on newer Apple silicon; must be 1 before per-fan modes accept manual control.
    public static let unlock = "Ftst"

    public static func actual(_ fan: Int) -> String { "F\(fan)Ac" }
    public static func minimum(_ fan: Int) -> String { "F\(fan)Mn" }
    public static func maximum(_ fan: Int) -> String { "F\(fan)Mx" }
    public static func target(_ fan: Int) -> String { "F\(fan)Tg" }
    public static func mode(_ fan: Int) -> String { "F\(fan)Md" }
    public static func lowercaseMode(_ fan: Int) -> String { "F\(fan)md" }
}

public enum FanControlMode: Int, Sendable {
    case automatic = 0
    case manual = 1
}

extension SMC {
    /// Some firmware names the per-fan mode key `F{n}md` instead of `F{n}Md`.
    public func modeKey(_ fan: Int) -> String {
        contains(FanKey.lowercaseMode(0)) ? FanKey.lowercaseMode(fan) : FanKey.mode(fan)
    }

    public var fanCount: Int {
        Int(readDouble(FanKey.count) ?? 0)
    }

    public func fans() -> [Fan] {
        (0..<fanCount).map { index in
            Fan(
                id: index,
                name: "Fan \(index + 1)",
                currentRPM: readDouble(FanKey.actual(index)) ?? 0,
                minimumRPM: readDouble(FanKey.minimum(index)) ?? 0,
                maximumRPM: readDouble(FanKey.maximum(index)) ?? 0,
                targetRPM: readDouble(FanKey.target(index)) ?? 0,
                isManual: readDouble(modeKey(index)).map(Int.init) == FanControlMode.manual.rawValue
            )
        }
    }
}
