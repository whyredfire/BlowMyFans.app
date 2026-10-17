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
    private(set) var errorMessage: String?

    @ObservationIgnored var onUpdate: (@MainActor () -> Void)?
    @ObservationIgnored private let database: ModelDatabase

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
        let sampler: HardwareSampler
        do {
            // Sensor discovery walks every SMC key; keep it off the main thread.
            sampler = try await Task.detached { [database] in try HardwareSampler(database: database) }.value
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        availableGroups = await sampler.availableGroups

        while !Task.isCancelled {
            let snapshot = await sampler.sample()
            fans = snapshot.fans
            temperatures = snapshot.temperatures
            onUpdate?()
            try? await Task.sleep(for: interval)
        }
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

    func sample() -> HardwareSnapshot {
        let fans = smc.fans().map { fan in
            var fan = fan
            fan.name = database.fanName(fan.id)
            return fan
        }
        return HardwareSnapshot(fans: fans, temperatures: sensors.read())
    }
}
