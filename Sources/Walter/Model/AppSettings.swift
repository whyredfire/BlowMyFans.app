import Foundation
import Observation
import ServiceManagement

@MainActor @Observable
final class AppSettings {
    /// Menu bar item values besides a sensor group id.
    nonisolated static let hottestCPU = "hottest-cpu"
    nonisolated static let iconOnly = "icon-only"

    var useFahrenheit: Bool {
        didSet { UserDefaults.standard.set(useFahrenheit, forKey: "useFahrenheit") }
    }

    var menuBarItem: String {
        didSet { UserDefaults.standard.set(menuBarItem, forKey: "menuBarItem") }
    }

    /// Lets Manual mode go below a fan's minimum and stop it entirely.
    var allowFanOff: Bool {
        didSet { UserDefaults.standard.set(allowFanOff, forKey: "allowFanOff") }
    }

    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var launchAtLoginError: String?

    init() {
        let defaults = UserDefaults.standard
        useFahrenheit = defaults.bool(forKey: "useFahrenheit")
        menuBarItem = defaults.string(forKey: "menuBarItem") ?? Self.hottestCPU
        allowFanOff = defaults.bool(forKey: "allowFanOff")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func format(_ celsius: Double) -> String {
        let value = useFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }
}
