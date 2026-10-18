import SwiftUI

@main
struct WalterApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.settings)
                .environment(appDelegate.monitor)
                .environment(appDelegate.controller)
                .environment(appDelegate.updater)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let monitor = HardwareMonitor()
    lazy var controller = FanController(monitor: monitor, settings: settings)
    let updater = AppUpdater()
    private var statusItem: StatusItemController?

    override init() {
        // Read by AppKit when creating status items: narrower spacing and highlight than the default (16).
        UserDefaults.standard.register(defaults: ["NSStatusItemSpacing": 10, "NSStatusItemSelectionPadding": 10])
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.essentialGroups = { [settings, controller] group in
            group.id == settings.menuBarItem
                || group.isCPU && (settings.menuBarItem == AppSettings.hottestCPU || controller.mode == .curve)
        }
        statusItem = StatusItemController(settings: settings, monitor: monitor, controller: controller)
    }
}
