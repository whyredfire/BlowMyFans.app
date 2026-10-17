import SMCKit

extension [SensorGroupReading] {
    var hottestCPU: Double? {
        filter(\.group.isCPU).compactMap(\.maximum).max()
    }

    /// Temperature for a group id, or the hottest CPU reading for `AppSettings.hottestCPU`.
    func temperature(for id: String) -> Double? {
        id == AppSettings.hottestCPU ? hottestCPU : first { $0.id == id }?.maximum
    }

    /// The most useful readings for a short list: one each of CPU, GPU, SSD and battery,
    /// followed by the rest in database order.
    var highlights: [SensorGroupReading] {
        func category(_ group: SensorGroup) -> Int? {
            if group.isCPU { return 0 }
            if group.isGPU { return 1 }
            if group.symbol == "internaldrive" { return 2 }
            if group.symbol.hasPrefix("battery") { return 3 }
            return nil
        }
        var seen = Set<Int>()
        let primary = filter { reading in
            guard let category = category(reading.group) else { return false }
            return seen.insert(category).inserted
        }
        let rest = filter { category($0.group) == nil }
        return primary.sorted { category($0.group)! < category($1.group)! } + rest
    }
}
