import SwiftUI

@main
struct BlowMyFansApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.settings)
                .environment(appDelegate.monitor)
                .environment(appDelegate.controller)
                .environment(appDelegate.updater)
                .environment(appDelegate.power)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let monitor: HardwareMonitor
    let power = PowerSourceMonitor()
    lazy var controller = FanController(monitor: monitor, settings: settings, power: power)
    let updater = AppUpdater()
    private var statusItem: StatusItemController?

    override init() {
        // Read by AppKit when creating status items: narrower spacing and highlight than the default (16).
        UserDefaults.standard.register(defaults: ["NSStatusItemSpacing": 10, "NSStatusItemSelectionPadding": 10])
        monitor = HardwareMonitor(interval: .seconds(settings.updateInterval))
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.essentialGroups = { [settings, controller] group in
            group.id == settings.menuBarItem
                || group.isCPU && (settings.menuBarItem == AppSettings.hottestCPU || controller.mode == .curve)
        }
        monitor.needsFans = { [controller] in controller.mode != .automatic }
        followUpdateInterval()
        statusItem = StatusItemController(settings: settings, monitor: monitor, controller: controller)
        if !isLaunchingAtLogin {
            statusItem?.showPanel()
        }
    }

    private func followUpdateInterval() {
        withObservationTracking {
            monitor.interval = .seconds(settings.updateInterval)
        } onChange: {
            Task { @MainActor in self.followUpdateInterval() }
        }
    }

    /// Opening the app again, e.g. from Finder or Spotlight, shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        statusItem?.showPanel()
        return false
    }

    /// The launch event's login-item flag isn't documented for apps registered with `SMAppService`,
    /// so launches within a minute of logging in count as well.
    private var isLaunchingAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        if event?.eventID == kAEOpenApplication,
           event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            return true
        }
        return Self.consoleLoginDate.map { Date.now.timeIntervalSince($0) < 60 } ?? false
    }

    private static var consoleLoginDate: Date? {
        setutxent()
        defer { endutxent() }
        while let entry = getutxent()?.pointee {
            let line = withUnsafeBytes(of: entry.ut_line) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            let user = withUnsafeBytes(of: entry.ut_user) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            if entry.ut_type == USER_PROCESS, line == "console", user == NSUserName() {
                return Date(timeIntervalSince1970: TimeInterval(entry.ut_tv.tv_sec))
            }
        }
        return nil
    }
}
