import Foundation
import Observation
import ServiceManagement

@MainActor @Observable
final class AppSettings {
    /// Menu bar item values besides a sensor group id.
    nonisolated static let hottestCPU = "hottest-cpu"
    nonisolated static let iconOnly = "icon-only"
    /// Choices for `updateInterval`, in seconds.
    nonisolated static let updateIntervals: [Double] = [1, 2, 5, 10]

    var useFahrenheit: Bool {
        didSet { UserDefaults.standard.set(useFahrenheit, forKey: "useFahrenheit") }
    }

    var menuBarItem: String {
        didSet { UserDefaults.standard.set(menuBarItem, forKey: "menuBarItem") }
    }

    /// Lets the fans stop: below the minimum in Manual mode, and where the curve is at 0% in Curve mode.
    var allowFanOff: Bool {
        didSet { UserDefaults.standard.set(allowFanOff, forKey: "allowFanOff") }
    }

    /// How often temperatures and fan speeds are read, in seconds.
    var updateInterval: Double {
        didSet { UserDefaults.standard.set(updateInterval, forKey: "updateInterval") }
    }

    /// Each power source keeps its own mode, applied when the Mac is plugged in or unplugged.
    var switchesModeWithPower: Bool {
        didSet { UserDefaults.standard.set(switchesModeWithPower, forKey: "switchesModeWithPower") }
    }

    private(set) var modes: [PowerSource: FanMode] {
        didSet {
            for (source, mode) in modes {
                UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey(source))
            }
        }
    }

    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var launchAtLoginError: String?

    init() {
        let defaults = UserDefaults.standard
        useFahrenheit = defaults.bool(forKey: "useFahrenheit")
        menuBarItem = defaults.string(forKey: "menuBarItem") ?? Self.hottestCPU
        allowFanOff = defaults.bool(forKey: "allowFanOff")
        let interval = defaults.double(forKey: "updateInterval")
        updateInterval = Self.updateIntervals.contains(interval) ? interval : 2
        switchesModeWithPower = defaults.bool(forKey: "switchesModeWithPower")
        modes = Dictionary(uniqueKeysWithValues: PowerSource.allCases.map { source in
            (source, defaults.string(forKey: Self.modeKey(source)).flatMap(FanMode.init(rawValue:)) ?? .automatic)
        })
    }

    func mode(for source: PowerSource) -> FanMode {
        modes[source] ?? .automatic
    }

    func setMode(_ mode: FanMode, for source: PowerSource) {
        modes[source] = mode
    }

    private static func modeKey(_ source: PowerSource) -> String {
        "\(source.rawValue)Mode"
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
