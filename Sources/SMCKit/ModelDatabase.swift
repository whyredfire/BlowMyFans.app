import Foundation

/// Per-model sensor and fan metadata, read from the JSON tables shipped with the app.
/// Each table is a list of blocks whose `models` say which Macs they apply to.
public struct ModelDatabase: Sendable {
    public let sensorGroups: [SensorGroup]
    /// Mac Studio and iMac Pro coolers run two synchronised fans as one.
    public let hasSynchronizedFans: Bool
    private let fanNames: [String]

    public init(directory: URL, modelIdentifier: String = Machine.modelIdentifier) {
        func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
            let url = directory.appending(path: "\(name).json")
            return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        }
        // Newer identifiers (e.g. `Mac16,8`) map to the database's names (e.g. `MacBookPro21,2`).
        let aliases = load("modelAliases", as: [String: String].self) ?? [:]
        let model = ModelID(aliases[modelIdentifier] ?? modelIdentifier)
        sensorGroups = Self.sensorGroups(load("smcSensors", as: [SensorBlock].self), source: .smc, model: model)
            + Self.sensorGroups(load("hidSensors", as: [SensorBlock].self), source: .hid, model: model)
        fanNames = load("fanNames", as: [FanBlock].self)?.last { model.matches(any: $0.models) }?.fans ?? []
        hasSynchronizedFans = ["macstudio", "imacpro"].contains(model.family.lowercased())
    }

    public func fanName(_ index: Int) -> String {
        index < fanNames.count ? fanNames[index] : "Fan \(index + 1)"
    }

    // MARK: - Tables

    private struct FanBlock: Decodable {
        let models: [String]
        let fans: [String]
    }

    private struct SensorBlock: Decodable {
        let models: [String]
        let sensors: [Item]
    }

    private struct SensorEntry: Decodable {
        let key: String
        var type: String?
        /// Removes the key added by an earlier block.
        var exclude: Bool?
        var label: String?
        /// One label per core when a key reports for several.
        var labels: [String]?
    }

    private enum Item: Decodable {
        case sensor(SensorEntry)
        case group(name: String, sensors: [SensorEntry])

        private enum CodingKeys: String, CodingKey {
            case group, sensors
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let name = try container.decodeIfPresent(String.self, forKey: .group) {
                self = .group(name: name, sensors: try container.decode([SensorEntry].self, forKey: .sensors))
            } else {
                self = .sensor(try SensorEntry(from: decoder))
            }
        }
    }

    // MARK: - Resolving

    private struct Entry {
        var key: String
        var label: String
        var type: String?
        var group: String?
    }

    private static func sensorGroups(_ blocks: [SensorBlock]?, source: SensorKey.Source, model: ModelID) -> [SensorGroup] {
        var entries: [Entry] = []

        func apply(_ sensor: SensorEntry, group: String?) {
            if sensor.exclude == true {
                entries.removeAll { $0.key == sensor.key }
                return
            }
            let label = compactLabel(sensor.labels ?? sensor.label.map { [$0] } ?? [])
            let entry = Entry(key: sensor.key, label: label.isEmpty ? sensor.key : label, type: sensor.type, group: group)
            if let index = entries.firstIndex(where: { $0.key == sensor.key }) {
                entries[index] = entry
            } else {
                entries.append(entry)
            }
        }

        for block in blocks ?? [] where model.matches(any: block.models) {
            for item in block.sensors {
                switch item {
                case .sensor(let sensor): apply(sensor, group: nil)
                case .group(let name, let sensors): sensors.forEach { apply($0, group: name) }
                }
            }
        }

        // Preserve database order; grouped sensors form one group, others stand alone.
        var order: [String] = []
        var grouped: [String: [Entry]] = [:]
        for entry in entries {
            let id = entry.group.map { "group:\($0)" } ?? "\(source):\(entry.key)"
            if grouped[id] == nil { order.append(id) }
            grouped[id, default: []].append(entry)
        }
        let groups = order.map { id in
            let members = grouped[id]!
            let first = members[0]
            return SensorGroup(
                id: id,
                name: first.group ?? first.label,
                symbol: symbol(type: first.type, name: first.group ?? first.label),
                isCPU: members.contains { $0.type == "cpu" },
                isGPU: members.contains { $0.type == "gpu" },
                sensors: members.map { source == .smc ? SensorKey(smc: $0.key, $0.label) : SensorKey(hid: $0.key, $0.label) }
            )
        }
        // CPU first, then GPU, then everything else in database order.
        return groups.enumerated().sorted { lhs, rhs in
            (rank(lhs.element), lhs.offset) < (rank(rhs.element), rhs.offset)
        }.map(\.element)
    }

    private static func rank(_ group: SensorGroup) -> Int {
        group.isCPU ? 0 : group.isGPU ? 1 : 2
    }

    /// Joins per-core labels: ["CPU Core 1", "CPU Core 7"] becomes "CPU Core 1 / 7".
    private static func compactLabel(_ parts: [String]) -> String {
        guard let first = parts.first, parts.count > 1, let space = first.lastIndex(of: " ") else {
            return parts.joined(separator: " / ")
        }
        let prefix = first[...space]
        return ([first] + parts.dropFirst().map { $0.hasPrefix(prefix) ? String($0.dropFirst(prefix.count)) : $0 })
            .joined(separator: " / ")
    }

    private static func symbol(type: String?, name: String) -> String {
        switch type {
        case "cpu": return "cpu"
        case "gpu": return "cube"
        case "psu": return "powerplug"
        case "airport": return "wifi"
        case "ssd": return "internaldrive"
        case "odd": return "opticaldiscdrive"
        default: break
        }
        let name = name.lowercased()
        if name.contains("battery") { return "battery.75percent" }
        if name.contains("trackpad") { return "rectangle.and.hand.point.up.left" }
        if name.contains("thunderbolt") { return "bolt" }
        if name.contains("lcd") || name.contains("display") { return "display" }
        return "thermometer.medium"
    }
}

/// A model identifier split into family and version, e.g. `MacBookPro21,2` → (`MacBookPro`, [21, 2]).
struct ModelID {
    let raw: String
    let family: String
    let version: [Int]

    init(_ raw: String) {
        self.raw = raw
        family = String(raw.prefix { $0.isLetter })
        version = raw.dropFirst(family.count).split(separator: ",").map { Int($0) ?? 0 }
    }

    /// Matches `all`, an exact identifier, or `Family N,M+` (this model and newer).
    func matches(_ pattern: String) -> Bool {
        if pattern == "all" { return true }
        if pattern.hasSuffix("+") {
            let minimum = ModelID(String(pattern.dropLast()))
            return family.caseInsensitiveCompare(minimum.family) == .orderedSame
                && !version.lexicographicallyPrecedes(minimum.version)
        }
        return raw.caseInsensitiveCompare(pattern) == .orderedSame
    }

    func matches(any patterns: [String]) -> Bool {
        patterns.contains(where: matches)
    }
}
