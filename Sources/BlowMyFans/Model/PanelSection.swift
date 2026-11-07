/// Parts of the panel that can be hidden in Settings.
enum PanelSection: String, CaseIterable, Identifiable {
    case fans, power, thermalPressure, temperatures

    var id: Self { self }

    var title: String {
        switch self {
        case .fans: String(localized: "Fan speeds")
        case .power: String(localized: "Power")
        case .thermalPressure: String(localized: "Thermal pressure")
        case .temperatures: String(localized: "Temperatures")
        }
    }
}
