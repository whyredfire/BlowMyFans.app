import AppKit

extension ProcessInfo.ThermalState {
    var title: String {
        switch self {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
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
