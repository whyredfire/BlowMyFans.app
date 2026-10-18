import Foundation
import Observation
import Sparkle

/// Sparkle's standard updater, plus the state the Settings window shows.
@MainActor @Observable
final class AppUpdater {
    @ObservationIgnored private let userDriverDelegate = BackgroundAppUserDriverDelegate()
    @ObservationIgnored private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)
    }

    var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var automaticallyChecks: Bool {
        get {
            access(keyPath: \.automaticallyChecks)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.automaticallyChecks) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// Walter lives in the menu bar, so scheduled update prompts shouldn't steal focus.
private final class BackgroundAppUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }
}
