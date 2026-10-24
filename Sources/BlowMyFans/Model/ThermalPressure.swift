import AppKit

extension ProcessInfo.ThermalState {
    var title: String {
        switch self {
        case .nominal: String(localized: "Nominal")
        case .fair: String(localized: "Fair")
        case .serious: String(localized: "Serious")
        case .critical: String(localized: "Critical")
        @unknown default: String(localized: "Unknown")
        }
    }

    /// Colour of the menu bar warning dot; nil when there's nothing to flag.
    var warningColor: NSColor? {
        switch self {
        case .nominal: nil
        case .fair: .systemYellow
        case .serious: .systemOrange
        case .critical: .systemRed
        @unknown default: .systemRed
        }
    }
}
