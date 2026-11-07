import SMCKit

extension [SensorGroupReading] {
    var hottestCPU: Double? {
        filter(\.group.isCPU).compactMap(\.maximum).max()
    }

    /// Temperature for a group id, or the hottest CPU reading for `AppSettings.hottestCPU`.
    func temperature(for id: String) -> Double? {
        id == AppSettings.hottestCPU ? hottestCPU : first { $0.id == id }?.maximum
    }

    var highlights: [SensorGroupReading] { highlights(by: \.group) }
}

extension [SensorGroup] {
    var highlights: [SensorGroup] { highlights { $0 } }

    /// What the panel lists unless the user picks.
    var panelDefaults: [SensorGroup] { Array(highlights.prefix(5)) }
}

extension Array {
    /// The most useful entries first: one each of CPU, GPU, SSD and battery, followed by
    /// everything else in database order.
    fileprivate func highlights(by group: (Element) -> SensorGroup) -> [Element] {
        func category(_ group: SensorGroup) -> Int? {
            if group.isCPU { return 0 }
            if group.isGPU { return 1 }
            if group.symbol == "internaldrive" { return 2 }
            if group.symbol.hasPrefix("battery") { return 3 }
            return nil
        }
        var seen = Set<Int>()
        let primary = filter { element in
            guard let category = category(group(element)) else { return false }
            return seen.insert(category).inserted
        }
        let primaryIDs = Set(primary.map { group($0).id })
        let rest = filter { !primaryIDs.contains(group($0).id) }
        return primary.sorted { category(group($0))! < category(group($1))! } + rest
    }
}
