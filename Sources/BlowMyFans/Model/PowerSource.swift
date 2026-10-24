import Foundation
import IOKit.ps
import Observation

enum PowerSource: String, CaseIterable, Identifiable {
    case adapter, battery

    var id: Self { self }

    var title: String {
        switch self {
        case .adapter: String(localized: "On power adapter")
        case .battery: String(localized: "On battery")
        }
    }
}

/// Whether the Mac runs on its power adapter or its battery, updated as macOS reports changes.
@MainActor @Observable
final class PowerSourceMonitor {
    private(set) var current: PowerSource
    /// Desktop Macs have no battery, so there's nothing to switch between.
    let hasBattery: Bool

    @ObservationIgnored var onChange: (@MainActor (PowerSource) -> Void)?

    init() {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        current = Self.source(in: snapshot)
        hasBattery = Self.hasBattery(in: snapshot)

        let context = Unmanaged.passUnretained(self).toOpaque()
        // Delivered on the main run loop; the monitor lives as long as the app.
        let notification = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }, context)
        if let source = notification?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private func refresh() {
        let source = Self.source(in: IOPSCopyPowerSourcesInfo()?.takeRetainedValue())
        guard source != current else { return }
        current = source
        onChange?(source)
    }

    private static func source(in snapshot: CFTypeRef?) -> PowerSource {
        let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        return type == kIOPMBatteryPowerKey ? .battery : .adapter
    }

    private static func hasBattery(in snapshot: CFTypeRef?) -> Bool {
        guard let snapshot, let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        return sources.contains { source in
            let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }
}
