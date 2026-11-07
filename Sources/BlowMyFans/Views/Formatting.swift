import Foundation
import SMCKit

extension SensorGroup {
    /// Name without trailing qualifiers, for compact rows.
    var shortName: String {
        let trimmed = [" Average", " (average)", " Proximity"].reduce(name) { name, suffix in
            name.hasSuffix(suffix) ? String(name.dropLast(suffix.count)) : name
        }
        return trimmed.isEmpty ? name : trimmed
    }
}

extension Double {
    var rpmText: String { "\(formatted(.number.precision(.fractionLength(0)))) RPM" }

    /// One decimal below 10 W.
    var wattsText: String {
        Measurement(value: self, unit: UnitPower.watts)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(abs(self) < 10 ? 1 : 0))))
    }
}
