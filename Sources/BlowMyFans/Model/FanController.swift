import AppKit
import HelperInterface
import Observation
import SMCKit

enum HelperStatus {
    case unknown, notInstalled, installing, installed
}

/// Owns the fan configuration and keeps the helper in sync with it.
@MainActor @Observable
final class FanController {
    private static let configurationKey = "fanConfiguration"

    /// The applied configuration.
    var configuration: FanConfiguration {
        didSet {
            draft = configuration
            guard configuration != oldValue else { return }
            UserDefaults.standard.setEncoded(configuration, forKey: Self.configurationKey)
            // Any change is the user acting, so give a paused mode another try.
            resume()
            sync()
        }
    }

    /// What the panel edits; nothing changes until it's applied.
    var draft: FanConfiguration
    var hasUnappliedChanges: Bool { pendingConfiguration != configuration }

    /// The draft's mode with only that mode's settings; edits made while browsing other modes are dropped.
    private var pendingConfiguration: FanConfiguration {
        var pending = configuration
        pending.mode = draft.mode
        switch draft.mode {
        case .manual: pending.manual = draft.manual
        case .curve: pending.curve = draft.curve
        case .automatic, .fullBlast: break
        }
        return pending
    }

    private(set) var helperStatus: HelperStatus = .unknown
    private(set) var errorMessage: String?
    @ObservationIgnored private var isTakingControl = false
    /// The saved mode is kept but not applied, after a failure or while the helper is missing.
    /// macOS controls the fans meanwhile and `errorMessage` says why.
    private(set) var isSuspended = false
    /// The CPU temperature Curve mode follows: rises are tracked quickly and falls slowly, so
    /// short load spikes don't make the fans surge up and back down.
    private(set) var curveTemperature: Double?

    var mode: FanMode { configuration.mode }

    @ObservationIgnored private let monitor: HardwareMonitor
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let helper = HelperClient()
    /// Speeds last confirmed by the helper; nil while macOS controls the fans.
    @ObservationIgnored private var appliedRPMs: [Double]?
    /// Bumped whenever the helper may have dropped applied speeds, so replies to calls made
    /// before that point aren't recorded as applied.
    @ObservationIgnored private var appliedGeneration = 0
    @ObservationIgnored private var isAsleep = false
    @ObservationIgnored private var isUninstalling = false
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherSync = false
    /// When the fans were first seen out of manual mode while speeds are applied.
    @ObservationIgnored private var lostControlSince: ContinuousClock.Instant?
    @ObservationIgnored private var nextControlRecovery = ContinuousClock.now
    @ObservationIgnored private var curveTemperatureDate = ContinuousClock.now

    init(monitor: HardwareMonitor, settings: AppSettings) {
        self.monitor = monitor
        self.settings = settings
        let defaults = UserDefaults.standard
        let configuration = defaults.decoded(FanConfiguration.self, forKey: Self.configurationKey) ?? FanConfiguration()
        self.configuration = configuration
        draft = configuration

        monitor.onUpdate = { [weak self] in self?.monitorDidUpdate() }
        helper.onConnectionLost = { [weak self] in self?.invalidateAppliedSpeeds() }

        // The helper hands fans to macOS for sleep itself; the app pauses and re-sends on wake.
        observeWorkspace(NSWorkspace.willSleepNotification) { controller in
            controller.isAsleep = true
        }
        observeWorkspace(NSWorkspace.didWakeNotification) { controller in
            controller.isAsleep = false
            controller.lostControlSince = nil
            controller.invalidateAppliedSpeeds()
        }

        Task {
            await refreshHelperStatus()
            // A saved mode must never trigger a password prompt at launch; wait for the user to act.
            if helperStatus != .installed, configuration.mode != .automatic {
                isSuspended = true
                errorMessage = "The fan helper isn't installed. Install it or choose a mode to resume \(mode.title)."
            }
            sync()
        }
    }

    func apply() {
        configuration = pendingConfiguration
    }

    func discardDraft() {
        draft = configuration
    }

    /// Tries a paused mode again.
    func retry() {
        resume()
        sync()
    }

    // MARK: Helper

    func refreshHelperStatus() async {
        let version = await helper.installedVersion()
        helperStatus = version == HelperIdentity.version ? .installed : .notInstalled
    }

    func installHelper() async {
        do {
            try await ensureHelper()
            errorMessage = nil
            isSuspended = false
            sync()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uninstallHelper() async {
        guard !isUninstalling else { return }
        isUninstalling = true
        // Let an in-flight sync finish so it can't re-apply speeds after the restore below.
        while let syncTask { await syncTask.value }

        if appliedRPMs != nil {
            appliedRPMs = nil
            try? await helper.restoreAutomatic()
        }

        var didUninstall = false
        do {
            try await HelperInstaller.uninstall()
            didUninstall = true
            errorMessage = nil
        } catch HelperInstallerError.cancelled {
            // Nothing changed; the current mode stays.
        } catch {
            errorMessage = error.localizedDescription
        }
        if didUninstall { helper.disconnect() }
        await refreshHelperStatus()
        isUninstalling = false

        if didUninstall, helperStatus != .installed {
            // Fans are back with macOS; reflect that rather than offering to reinstall on the next sync.
            isSuspended = false
            configuration.mode = .automatic
        }
        sync()
    }

    // MARK: Syncing

    private enum SyncTarget {
        /// Leave the fans to macOS.
        case automatic
        /// Readings are unusable; keep whatever is applied.
        case hold
        case speeds([Double])
    }

    /// Clears a suspension so the saved mode is applied again on the next sync.
    private func resume() {
        guard isSuspended else { return }
        isSuspended = false
        errorMessage = nil
    }

    private func monitorDidUpdate() {
        updateCurveTemperature()
        detectLostControl()
        // With macOS in charge and nothing applied there's nothing to send.
        let isLeftToMacOS = isSuspended || configuration.mode == .automatic
        if !isLeftToMacOS || appliedRPMs != nil {
            sync()
        }
    }

    /// Exponential smoothing that follows time rather than readings, so it behaves the same at any
    /// update interval: ~75% of a rise within 4 s, ~90% of a fall in about 30 s.
    private func updateCurveTemperature() {
        let now = ContinuousClock.now
        defer { curveTemperatureDate = now }
        guard let current = monitor.temperatures.hottestCPU else {
            curveTemperature = nil
            return
        }
        guard let previous = curveTemperature else {
            curveTemperature = current
            return
        }
        let weightPerTwoSeconds = current > previous ? 0.5 : 0.15
        let weight = 1 - pow(1 - weightPerTwoSeconds, (now - curveTemperatureDate) / .seconds(2))
        curveTemperature = previous + (current - previous) * weight
    }

    /// Re-sends the target if fans stay out of manual mode for 6 s while we believe speeds are
    /// applied (e.g. the helper gave up re-applying them). The helper's own watchdog gets those first
    /// seconds, and recovery is rate-limited.
    private func detectLostControl() {
        guard let applied = appliedRPMs, !isTakingControl, !isAsleep, syncTask == nil,
              monitor.fans.count == applied.count,
              monitor.fans.contains(where: { !$0.isManual }) else {
            lostControlSince = nil
            return
        }
        let now = ContinuousClock.now
        let since = lostControlSince ?? now
        lostControlSince = since
        guard now - since >= .seconds(6), now >= nextControlRecovery else { return }
        lostControlSince = nil
        nextControlRecovery = now + .seconds(30)
        invalidateAppliedSpeeds()
    }

    /// Forgets what the helper was told so the next sync re-sends it.
    private func invalidateAppliedSpeeds() {
        appliedRPMs = nil
        appliedGeneration &+= 1
        sync()
    }

    /// Coalesces requests so only one sync talks to the helper at a time.
    private func sync() {
        guard !isUninstalling else { return }
        guard syncTask == nil else {
            needsAnotherSync = true
            return
        }
        syncTask = Task {
            repeat {
                needsAnotherSync = false
                await syncNow()
            } while needsAnotherSync && !isUninstalling
            syncTask = nil
        }
    }

    private func desiredTarget() -> SyncTarget {
        guard !isSuspended, configuration.mode != .automatic else { return .automatic }
        let fans = monitor.fans
        // A failed SMC read reports 0 RPM limits; never turn that into a speed (0 would stop the fan).
        guard !fans.isEmpty, fans.allSatisfy(\.hasUsableSpeedRange) else { return .hold }
        let target = configuration.targetRPMs(
            for: fans,
            cpuTemperature: curveTemperature,
            allowFanOff: settings.allowFanOff,
            sliderMinimum: monitor.fanSpeedRange?.lowerBound
        )
        return target.map(SyncTarget.speeds) ?? .automatic
    }

    private func syncNow() async {
        guard helperStatus != .unknown, !isAsleep, !isUninstalling else { return }
        let generation = appliedGeneration

        do {
            switch desiredTarget() {
            case .hold:
                return
            case .speeds(let target):
                guard target != appliedRPMs else { return }
                isTakingControl = appliedRPMs == nil
                defer { isTakingControl = false }
                try await ensureHelper()
                try await helper.setFanSpeeds(target)
                guard generation == appliedGeneration else {
                    // The helper may have dropped these meanwhile; send them again.
                    needsAnotherSync = true
                    return
                }
                appliedRPMs = target
            case .automatic:
                guard appliedRPMs != nil else { return }
                appliedRPMs = nil
                try await helper.restoreAutomatic()
            }
            if !isSuspended { errorMessage = nil }
        } catch {
            await handleSyncFailure(error)
        }
    }

    /// Pauses the mode without changing the saved configuration. The helper has already
    /// handed the fans back to macOS (it rolls back failed writes and drops lost clients).
    private func handleSyncFailure(_ error: Error) async {
        appliedRPMs = nil
        if configuration.mode != .automatic {
            isSuspended = true
            errorMessage = "\(error.localizedDescription) \(mode.title) is paused until you choose a mode."
        } else {
            errorMessage = error.localizedDescription
        }
        // Anything but an error reported by the helper itself means it may be gone; re-check so
        // the UI offers to install it again.
        switch error {
        case HelperClientError.failed, is HelperInstallerError: break
        default: await refreshHelperStatus()
        }
    }

    private func ensureHelper() async throws {
        if helperStatus != .installed { await refreshHelperStatus() }
        guard helperStatus != .installed else { return }

        helperStatus = .installing
        do {
            try await HelperInstaller.install()
        } catch {
            helperStatus = .notInstalled
            throw error
        }

        // launchd may need a moment before the new mach service answers.
        helper.disconnect()
        for _ in 0..<10 {
            if await helper.installedVersion() == HelperIdentity.version {
                helperStatus = .installed
                return
            }
            try await Task.sleep(for: .milliseconds(300))
        }
        helperStatus = .notInstalled
        throw HelperClientError.unreachable
    }

    private func observeWorkspace(_ name: Notification.Name, handler: @escaping @MainActor @Sendable (FanController) -> Void) {
        NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
    }
}
