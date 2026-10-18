import SMCKit
import SwiftUI

struct FanRow: View {
    let fan: Fan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "fan")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.rotate, isActive: fan.currentRPM > 0)
                    .frame(width: 18)
                Text(fan.name)
                Spacer()
                Text(fan.currentRPM > 0 ? fan.currentRPM.rpmText : "Off")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: fan.currentRPM))
            }
            LevelBar(fraction: fan.maximumRPM > 0 ? fan.currentRPM / fan.maximumRPM : 0)
                .padding(.leading, 26)
        }
        .animation(.smooth, value: fan.currentRPM)
    }
}

private struct LevelBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(Color.accentColor.gradient)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
        .animation(.smooth, value: fraction)
    }
}

struct TemperatureRow: View {
    let reading: SensorGroupReading

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: reading.group.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(reading.group.shortName)
                .lineLimit(1)
            Spacer()
            if let maximum = reading.maximum {
                TemperatureText(celsius: maximum)
            }
        }
        .help(reading.group.name)
    }
}

private struct TemperatureText: View {
    @Environment(AppSettings.self) private var settings
    let celsius: Double

    var body: some View {
        Text(settings.format(celsius))
            .monospacedDigit()
            .foregroundStyle(tint)
            .contentTransition(.numericText(value: celsius))
            .animation(.smooth, value: celsius)
    }

    private var tint: Color {
        switch celsius {
        case 95...: .red
        case 80...: .orange
        default: .primary
        }
    }
}

struct ThermalPressureRow: View {
    let state: ProcessInfo.ThermalState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text("Thermal pressure")
            Spacer()
            Circle()
                .fill(Color(nsColor: state.warningColor ?? .systemGreen))
                .frame(width: 7, height: 7)
            Text(state.title)
                .foregroundStyle(.secondary)
        }
    }
}
