import Foundation

public struct SensorGroup: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let symbol: String
    public let isCPU: Bool
    public let isGPU: Bool
    /// Known sensors with labels.
    let sensors: [SensorKey]
    /// SMC key prefixes, used when no model-specific sensors are known.
    let prefixes: [String]

    init(id: String, name: String, symbol: String, isCPU: Bool = false, isGPU: Bool = false, sensors: [SensorKey] = [], prefixes: [String] = []) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.isCPU = isCPU
        self.isGPU = isGPU
        self.sensors = sensors
        self.prefixes = prefixes
    }

    func members(smcKeys: Set<String>, hidNames: Set<String>) -> [SensorKey] {
        let curated = sensors.filter { sensor in
            switch sensor.source {
            case .smc: smcKeys.contains(sensor.key)
            case .hid: hidNames.contains(sensor.key)
            }
        }
        let matched = smcKeys.sorted()
            .filter { key in prefixes.contains { key.hasPrefix($0) } }
            .map { SensorKey(smc: $0, $0) }
        return curated + matched
    }

    /// Generic groups for Macs the model database doesn't know yet.
    static let fallback = [
        SensorGroup(id: "fallback-cpu-p", name: "CPU Performance Cores", symbol: "cpu", isCPU: true, prefixes: ["Tp"]),
        SensorGroup(id: "fallback-cpu-e", name: "CPU Efficiency Cores", symbol: "cpu", isCPU: true, prefixes: ["Te"]),
        SensorGroup(id: "fallback-gpu", name: "GPU", symbol: "cube", isGPU: true, prefixes: ["Tg"]),
    ]
}

struct SensorKey: Sendable, Hashable {
    enum Source: Sendable, Hashable { case smc, hid }

    let source: Source
    let key: String
    let label: String

    init(smc key: String, _ label: String) {
        (source, self.key, self.label) = (.smc, key, label)
    }

    init(hid name: String, _ label: String) {
        (source, key, self.label) = (.hid, name, label)
    }
}

public struct Sensor: Identifiable, Sendable, Hashable {
    public let id: String
    public let label: String
    public let celsius: Double
}

public struct SensorGroupReading: Identifiable, Sendable, Hashable {
    public let group: SensorGroup
    public let sensors: [Sensor]

    public var id: String { group.id }
    public var maximum: Double? { sensors.map(\.celsius).max() }
}

/// Discovers which sensors exist once, then reads them on demand.
public struct SensorReader: Sendable {
    /// Power-gated or absent sensors report values outside this window.
    static let plausibleRange = 10.0...115.0
    /// How long a sensor keeps its last plausible value before it is dropped.
    static let holdDuration: TimeInterval = 30

    private let smc: SMC
    private let hid = HIDTemperatureSensors()
    private let groups: [(SensorGroup, [SensorKey])]
    private let members: [SensorKey]
    private let hidNames: Set<String>
    private var lastValues: [String: (celsius: Double, date: Date)] = [:]

    /// Groups with at least one sensor present on this Mac.
    public var availableGroups: [SensorGroup] { groups.map(\.0) }

    public init(smc: SMC, database: ModelDatabase) {
        self.smc = smc
        let smcKeys = Set(((try? smc.allKeys()) ?? []).filter { key in
            key.hasPrefix("T") && ["flt ", "sp78"].contains((try? smc.info(key))?.type)
        })
        let availableHID = hid.names

        func resolve(_ groups: [SensorGroup]) -> [(SensorGroup, [SensorKey])] {
            groups.compactMap { group in
                let members = group.members(smcKeys: smcKeys, hidNames: availableHID)
                return members.isEmpty ? nil : (group, members)
            }
        }

        var groups = resolve(database.sensorGroups)
        if !groups.contains(where: \.0.isCPU) {
            groups = resolve(SensorGroup.fallback) + groups
        }
        self.groups = groups
        members = groups.flatMap(\.1)
        hidNames = Set(members.filter { $0.source == .hid }.map(\.key))
    }

    /// Sensors that briefly report implausible values keep their last good reading,
    /// so the list stays stable between polls.
    public mutating func read() -> [SensorGroupReading] {
        let now = Date.now
        let hidValues = hid.read(hidNames)
        for member in members {
            let value = switch member.source {
            case .smc: smc.readDouble(member.key)
            case .hid: hidValues[member.key]
            }
            if let value, Self.plausibleRange.contains(value) {
                lastValues[member.key] = (value, now)
            }
        }

        return groups.compactMap { group, members in
            let sensors = members.compactMap { member -> Sensor? in
                guard let last = lastValues[member.key],
                      now.timeIntervalSince(last.date) < Self.holdDuration else { return nil }
                return Sensor(id: member.key, label: member.label, celsius: last.celsius)
            }
            return sensors.isEmpty ? nil : SensorGroupReading(group: group, sensors: sensors)
        }
    }
}
