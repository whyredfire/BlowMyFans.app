import Foundation

struct CurvePoint: Codable, Equatable, Identifiable {
    var id = UUID()
    var temperature: Double
    /// Fraction of each fan's range: 0 = minimum RPM, 1 = maximum RPM.
    var speed: Double
}

extension CurvePoint {
    private enum CodingKeys: String, CodingKey {
        case id, temperature, speed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.value(for: .id, default: UUID())
        temperature = try container.decode(Double.self, forKey: .temperature)
        speed = try container.decode(Double.self, forKey: .speed)
    }
}

/// Fan speed as a function of CPU temperature: a smooth curve through points sorted by
/// temperature that never goes down as temperature rises.
struct FanCurve: Codable, Equatable {
    static let temperatureRange = 30.0...100.0
    /// Keeps neighbouring points apart so the curve stays a function of temperature.
    private static let spacing = 2.0

    private(set) var points = [
        CurvePoint(temperature: 45, speed: 0),
        CurvePoint(temperature: 60, speed: 0.25),
        CurvePoint(temperature: 75, speed: 0.6),
        CurvePoint(temperature: 90, speed: 1),
    ]

    /// Cubic Hermite interpolation with Steffen's monotone slopes: passes through every point
    /// without overshooting, so the curve stays non-decreasing.
    func speed(at celsius: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 1 }
        if celsius <= first.temperature { return first.speed }
        if celsius >= last.temperature { return last.speed }
        guard let index = points.lastIndex(where: { $0.temperature <= celsius }) else { return first.speed }
        let (a, b) = (points[index], points[index + 1])
        let width = b.temperature - a.temperature
        guard width > 0 else { return b.speed }

        let t = (celsius - a.temperature) / width
        let (t2, t3) = (t * t, t * t * t)
        let value = (2 * t3 - 3 * t2 + 1) * a.speed
            + (t3 - 2 * t2 + t) * width * slope(at: index)
            + (-2 * t3 + 3 * t2) * b.speed
            + (t3 - t2) * width * slope(at: index + 1)
        return min(max(value, 0), 1)
    }

    /// Zero at the ends so the curve meets its flat extensions smoothly.
    private func slope(at index: Int) -> Double {
        guard index > 0, index < points.count - 1 else { return 0 }
        let (previous, point, next) = (points[index - 1], points[index], points[index + 1])
        let (h0, h1) = (point.temperature - previous.temperature, next.temperature - point.temperature)
        let (s0, s1) = ((point.speed - previous.speed) / h0, (next.speed - point.speed) / h1)
        guard s0 > 0, s1 > 0 else { return 0 }
        let parabolic = (s0 * h1 + s1 * h0) / (h0 + h1)
        return 2 * min(s0, s1, 0.5 * parabolic)
    }

    /// Moves a point between its neighbours' temperatures. Raising it lifts later points to at
    /// least its speed; lowering it brings earlier points down to at most its speed.
    mutating func move(_ id: CurvePoint.ID, temperature: Double, speed: Double) {
        guard let index = points.firstIndex(where: { $0.id == id }) else { return }
        let lower = index > 0 ? points[index - 1].temperature + Self.spacing : Self.temperatureRange.lowerBound
        let upper = index < points.count - 1 ? points[index + 1].temperature - Self.spacing : Self.temperatureRange.upperBound
        let speed = min(max(speed, 0), 1)
        points[index].temperature = min(max(temperature, lower), upper).rounded()
        points[index].speed = speed
        for later in points.indices.dropFirst(index + 1) {
            points[later].speed = max(points[later].speed, speed)
        }
        for earlier in points.indices.prefix(index) {
            points[earlier].speed = min(points[earlier].speed, speed)
        }
    }

    mutating func add(temperature: Double, speed: Double) {
        let temperature = temperature.rounded()
        guard Self.temperatureRange.contains(temperature),
              !points.contains(where: { abs($0.temperature - temperature) < Self.spacing }) else { return }
        let index = points.firstIndex { $0.temperature > temperature } ?? points.count
        let floor = index > 0 ? points[index - 1].speed : 0
        let ceiling = index < points.count ? points[index].speed : 1
        points.insert(CurvePoint(temperature: temperature, speed: min(max(speed, floor), ceiling)), at: index)
    }

    mutating func remove(_ id: CurvePoint.ID) {
        guard points.count > 2 else { return }
        points.removeAll { $0.id == id }
    }

    /// Points sorted by temperature with unique ids and non-decreasing speeds, or nil unless
    /// there are at least two points at distinct, finite temperatures with speeds in 0...1.
    private static func validated(_ points: [CurvePoint]) -> [CurvePoint]? {
        let sorted = points.sorted { $0.temperature < $1.temperature }
        guard sorted.count >= 2,
              sorted.allSatisfy({ $0.temperature.isFinite && (0...1).contains($0.speed) }),
              zip(sorted, sorted.dropFirst()).allSatisfy({ $0.temperature < $1.temperature }) else { return nil }
        var seen = Set<CurvePoint.ID>()
        var floor = 0.0
        return sorted.map { point in
            var point = point
            if !seen.insert(point.id).inserted { point.id = UUID() }
            point.speed = max(point.speed, floor)
            floor = point.speed
            return point
        }
    }
}

extension FanCurve {
    private enum CodingKeys: String, CodingKey {
        case points
    }

    /// Falls back to the default curve if the stored points are missing or invalid.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        if let stored = try? container.decodeIfPresent([CurvePoint].self, forKey: .points),
           let valid = Self.validated(stored) {
            points = valid
        }
    }
}
