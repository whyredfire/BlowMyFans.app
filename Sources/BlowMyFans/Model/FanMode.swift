enum FanMode: String, CaseIterable, Identifiable, Codable {
    case automatic, manual, curve, fullBlast

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Auto", comment: "Fan mode, one of four in a narrow segmented control. Keep it to one short word.")
        case .manual: String(localized: "Manual", comment: "Fan mode, one of four in a narrow segmented control. Keep it to one short word.")
        case .curve: String(localized: "Curve", comment: "Fan mode, one of four in a narrow segmented control. Keep it to one short word.")
        case .fullBlast: String(localized: "Full Blast", comment: "Fan mode, one of four in a narrow segmented control. Keep it to one short word.")
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
