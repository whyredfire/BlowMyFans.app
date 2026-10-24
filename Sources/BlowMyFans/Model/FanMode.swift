enum FanMode: String, CaseIterable, Identifiable, Codable {
    case automatic, manual, curve, fullBlast

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: "Auto"
        case .manual: "Manual"
        case .curve: "Curve"
        case .fullBlast: "Full Blast"
        }
    }

    var symbol: String {
        switch self {
        case .automatic: "fan"
        case .manual: "fan.fill"
        case .curve: "chart.xyaxis.line"
        case .fullBlast: "wind"
        }
    }

    /// Unknown stored values fall back to automatic.
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = FanMode(rawValue: rawValue) ?? .automatic
    }
}
