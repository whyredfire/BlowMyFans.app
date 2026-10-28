import Foundation
import Observation
import SMCKit

/// Polls fans and temperature sensors and publishes the latest readings. Only what's shown or
/// acted on is read: some sensors take milliseconds each, and every SMC read is a firmware call.
@MainActor @Observable
final class HardwareMonitor {
    /// How many sensor groups the panel lists.
    static let panelGroupCount = 5
    /// How often the CPU temperature is read while fan control follows it, whatever `interval` is.
    static let controlInterval = Duration.seconds(2)

    /// Every fan the SMC reports, in hardware order.
    private(set) var fans: [Fan] = []
    private(set) var temperatures: [SensorGroupReading] = []
    /// Sensor groups present on this Mac, whether or not they currently report a value.
    private(set) var availableGroups: [SensorGroup] = []
    private(set) var thermalState = ProcessInfo.processInfo.thermalState
    private(set) var errorMessage: String?

    /// Called after every reading. `didRefresh` is false for the CPU-only readings taken between updates.
    @ObservationIgnored var onUpdate: (@MainActor (_ didRefresh: Bool) -> Void)?
    /// Time between updates of the published readings. A change takes effect straight away.
    @ObservationIgnored var interval: Duration {
        didSet {
            if interval != oldValue, sampler != nil { startPolling() }
        }
    }
    /// Fan control follows the CPU temperature (Curve mode), so it's read every `controlInterval`
    /// even when the published readings update less often.
    @ObservationIgnored var followsCPUTemperature = false {
        didSet {
            if followsCPUTemperature != oldValue, sampler != nil { startPolling() }
        }
    }
    /// The hottest CPU core as last read; between updates too while `followsCPUTemperature`.
    @ObservationIgnored private(set) var cpuTemperature: Double?
    /// Sensor groups the menu bar and fan control need while the panel is closed.
    @ObservationIgnored var essentialGroups: (SensorGroup) -> Bool = { _ in true }
    /// Whether fan control needs fan readings while the panel is closed.
    @ObservationIgnored var needsFans: () -> Bool = { true }
    @ObservationIgnored var isShowingDetails = false {
        didSet {
            if isShowingDetails, !oldValue { Task { await sample() } }
        }
    }
    @ObservationIgnored private let database: ModelDatabase
    @ObservationIgnored private var sampler: HardwareSampler?
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    /// Fans as presented to the user; synchronised dual-fan coolers show as one.
    var visibleFans: [Fan] {
        hasSynchronizedFans ? Array(fans.prefix(1)) : fans
    }

    var hasSynchronizedFans: Bool { database.hasSynchronizedFans && fans.count > 1 }

    var fanSpeedRange: ClosedRange<Double>? {
        guard let lower = fans.map(\.minimumRPM).min(),
              let upper = fans.map(\.maximumRPM).max(),
              lower < upper else { return nil }
        return lower...upper
    }

    var panelTemperatures: ArraySlice<SensorGroupReading> {
        temperatures.highlights.prefix(Self.panelGroupCount)
    }

    init(interval: Duration) {
        self.interval = interval
        let directory = Bundle.main.resourceURL?.appending(path: "Database") ?? URL(filePath: "/")
        database = ModelDatabase(directory: directory)
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.thermalState = ProcessInfo.processInfo.thermalState }
        }
        Task { await start() }
    }

    private func start() async {
        do {
            // Sensor discovery walks every SMC key; keep it off the main thread.
            let sampler = try await Task.detached { [database] in try HardwareSampler(database: database) }.value
            availableGroups = await sampler.availableGroups
            self.sampler = sampler
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        startPolling()
    }

    /// Updates straight away, then every `interval`; while fan control follows the CPU temperature,
    /// reads just that in between, every `controlInterval`. Replaces any running loop.
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var nextRefresh = ContinuousClock.now
            while !Task.isCancelled {
                guard let self else { return }
                let tick = followsCPUTemperature ? min(interval, Self.controlInterval) : interval
                let now = ContinuousClock.now
                // An update due within half a tick happens now rather than a whole tick late.
                let didRefresh = now >= nextRefresh - tick / 2
                if didRefresh {
                    // After a late wake, e.g. from sleep, carry on from now instead of catching up.
                    nextRefresh = max(nextRefresh + interval, now + interval / 2)
                    await sample()
                } else {
                    await sampleCPU()
                }
                // A loop replaced while reading must not report after its successor has started.
                guard !Task.isCancelled else { return }
                onUpdate?(didRefresh)
                try? await Task.sleep(for: tick, tolerance: tick / 4)
            }
        }
    }

    /// Reads only the CPU sensors, for fan control between updates. Nothing is published.
    private func sampleCPU() async {
        guard let sampler else { return }
        let groupIDs = Set(availableGroups.filter(\.isCPU).map(\.id))
        cpuTemperature = await sampler.sample(groupIDs: groupIDs, includeFans: false).temperatures.hottestCPU
    }

    private func sample() async {
        guard let sampler else { return }
        var groupIDs = Set(availableGroups.filter(essentialGroups).map(\.id))
        if isShowingDetails {
            groupIDs.formUnion(availableGroups.highlights.prefix(Self.panelGroupCount).map(\.id))
        }
        let includeFans = isShowingDetails || needsFans()
        guard includeFans || !groupIDs.isEmpty else { return }

        let snapshot = await sampler.sample(groupIDs: groupIDs, includeFans: includeFans)
        // Unchanged values aren't reassigned, so observers only hear about real changes.
        if let fans = snapshot.fans, fans != self.fans {
            self.fans = fans
        }
        // While the panel is closed, groups that weren't read keep their last reading so it has
        // something to show the moment it opens; it reads them again straight away.
        let kept = isShowingDetails ? [] : temperatures.filter { !groupIDs.contains($0.id) }
        let order = Dictionary(uniqueKeysWithValues: availableGroups.enumerated().map { ($1.id, $0) })
        let temperatures = (kept + snapshot.temperatures).sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }
        if temperatures != self.temperatures {
            self.temperatures = temperatures
        }
        cpuTemperature = temperatures.hottestCPU
    }
}

private struct HardwareSnapshot: Sendable {
    /// Nil when fans weren't read.
    let fans: [Fan]?
    let temperatures: [SensorGroupReading]
}

/// Keeps blocking SMC reads off the main actor.
private actor HardwareSampler {
    private let smc: SMC
    private let database: ModelDatabase
    private var sensors: SensorReader
    private var fans: [Fan] = []
    /// The fan count and speed limits don't change, so once they've read back usable only the
    /// values that change at runtime are read.
    private var hasFanLimits = false

    init(database: ModelDatabase) throws {
        smc = try SMC()
        self.database = database
        sensors = SensorReader(smc: smc, database: database)
    }

    var availableGroups: [SensorGroup] { sensors.availableGroups }

    func sample(groupIDs: Set<String>, includeFans: Bool) -> HardwareSnapshot {
        HardwareSnapshot(fans: includeFans ? readFans() : nil, temperatures: sensors.read(groupIDs: groupIDs))
    }

    private func readFans() -> [Fan] {
        if hasFanLimits {
            fans = fans.map(smc.refreshed)
        } else {
            fans = smc.fans().map { fan in
                var fan = fan
                fan.name = database.fanName(fan.id)
                return fan
            }
            hasFanLimits = !fans.isEmpty && fans.allSatisfy(\.hasUsableSpeedRange)
        }
        return fans
    }
}
