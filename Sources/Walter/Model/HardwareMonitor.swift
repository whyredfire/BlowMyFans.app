import Foundation
import Observation
import SMCKit

/// Polls fans and temperature sensors and publishes the latest readings.
@MainActor @Observable
final class HardwareMonitor {
    /// Every fan the SMC reports, in hardware order.
    private(set) var fans: [Fan] = []
    private(set) var temperatures: [SensorGroupReading] = []
    /// Sensor groups present on this Mac, whether or not they currently report a value.
    private(set) var availableGroups: [SensorGroup] = []
    private(set) var thermalState = ProcessInfo.processInfo.thermalState
    private(set) var errorMessage: String?

    @ObservationIgnored var onUpdate: (@MainActor () -> Void)?
    /// Sensor groups the menu bar and fan control need. Only these are read while the panel is closed.
    @ObservationIgnored var essentialGroups: (SensorGroup) -> Bool = { _ in true }
    @ObservationIgnored var isShowingDetails = false {
        didSet {
            if isShowingDetails, !oldValue { Task { await sample() } }
        }
    }
    @ObservationIgnored private let database: ModelDatabase
    @ObservationIgnored private var sampler: HardwareSampler?

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

    init(interval: Duration = .seconds(2)) {
        let directory = Bundle.main.resourceURL?.appending(path: "Database") ?? URL(filePath: "/")
        database = ModelDatabase(directory: directory)
        Task { await poll(every: interval) }
    }

    private func poll(every interval: Duration) async {
        do {
            // Sensor discovery walks every SMC key; keep it off the main thread.
            let sampler = try await Task.detached { [database] in try HardwareSampler(database: database) }.value
            availableGroups = await sampler.availableGroups
            self.sampler = sampler
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        while !Task.isCancelled {
            await sample()
            onUpdate?()
            try? await Task.sleep(for: interval, tolerance: interval / 4)
        }
    }

    private func sample() async {
        guard let sampler else { return }
        let groupIDs = isShowingDetails ? nil : Set(availableGroups.filter(essentialGroups).map(\.id))
        let snapshot = await sampler.sample(groupIDs: groupIDs)
        fans = snapshot.fans
        if let groupIDs {
            // Groups that weren't read keep their last reading until the panel opens and refreshes them.
            let order = Dictionary(uniqueKeysWithValues: availableGroups.enumerated().map { ($1.id, $0) })
            temperatures = (temperatures.filter { !groupIDs.contains($0.id) } + snapshot.temperatures)
                .sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }
        } else {
            temperatures = snapshot.temperatures
        }
        thermalState = ProcessInfo.processInfo.thermalState
    }
}

private struct HardwareSnapshot: Sendable {
    let fans: [Fan]
    let temperatures: [SensorGroupReading]
}

/// Keeps blocking SMC reads off the main actor.
private actor HardwareSampler {
    private let smc: SMC
    private let database: ModelDatabase
    private var sensors: SensorReader

    init(database: ModelDatabase) throws {
        smc = try SMC()
        self.database = database
        sensors = SensorReader(smc: smc, database: database)
    }

    var availableGroups: [SensorGroup] { sensors.availableGroups }

    func sample(groupIDs: Set<String>?) -> HardwareSnapshot {
        let fans = smc.fans().map { fan in
            var fan = fan
            fan.name = database.fanName(fan.id)
            return fan
        }
        return HardwareSnapshot(fans: fans, temperatures: sensors.read(groupIDs: groupIDs))
    }
}
