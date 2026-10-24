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
}

extension Array {
    /// The most useful entries for a short list: one each of CPU, GPU, SSD and battery,
    /// followed by the rest in database order.
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
        let rest = filter { category(group($0)) == nil }
        return primary.sorted { category(group($0))! < category(group($1))! } + rest
    }
}
