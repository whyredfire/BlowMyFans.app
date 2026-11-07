/// Watts in from the adapter and out of the battery, which is negative while it charges.
public struct PowerFlow: Sendable, Equatable {
    public var adapter: Double
    public var battery: Double
    public var hasBattery: Bool

    public var system: Double { adapter + battery }

    public init(adapter: Double, battery: Double, hasBattery: Bool) {
        self.adapter = adapter
        self.battery = battery
        self.hasBattery = hasBattery
    }
}

public enum PowerKey {
    public static let adapter = "PDTR"
    public static let battery = "SBAP"
}

extension SMC {
    public func powerFlow() -> PowerFlow? {
        let adapter = readDouble(PowerKey.adapter)
        let battery = readDouble(PowerKey.battery)
        guard adapter != nil || battery != nil else { return nil }
        // A battery held at its charge limit still trickles a few hundred milliwatts.
        func settled(_ watts: Double?, below threshold: Double) -> Double {
            guard let watts, watts.isFinite, abs(watts) >= threshold else { return 0 }
            return watts
        }
        return PowerFlow(
            adapter: max(settled(adapter, below: 0.05), 0),
            battery: settled(battery, below: 0.5),
            hasBattery: battery != nil
        )
    }
}
