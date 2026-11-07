import SMCKit
import SwiftUI

struct FanRow: View {
    let fan: Fan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "fan")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(fan.name)
                Spacer()
                Text(fan.currentRPM > 0 ? fan.currentRPM.rpmText : String(localized: "Off"))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            LevelBar(fraction: fan.maximumRPM > 0 ? fan.currentRPM / fan.maximumRPM : 0)
                .padding(.leading, 26)
        }
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

/// Where the power comes from, on the left, and where it goes, on the right.
struct PowerFlowRow: View {
    let flow: PowerFlow

    var body: some View {
        HStack(spacing: 10) {
            column(sources)
            Image(systemName: "arrow.right")
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
            column(destinations)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((sources + destinations).map { "\($0.title) \($0.watts.wattsText)" }.joined(separator: ", "))
    }

    private var sources: [PowerNode] {
        [
            flow.adapter > 0 ? PowerNode(symbol: "bolt.fill", title: String(localized: "Power adapter"), watts: flow.adapter) : nil,
            flow.battery > 0 ? PowerNode(symbol: "battery.75percent", title: String(localized: "Battery"), watts: flow.battery) : nil,
        ].compactMap(\.self)
    }

    private var destinations: [PowerNode] {
        [
            PowerNode(symbol: flow.hasBattery ? "laptopcomputer" : "desktopcomputer", title: String(localized: "This Mac"), watts: flow.system),
            flow.battery < 0 ? PowerNode(symbol: "battery.100percent.bolt", title: String(localized: "Charging"), watts: -flow.battery) : nil,
        ].compactMap(\.self)
    }

    private func column(_ nodes: [PowerNode]) -> some View {
        VStack(spacing: 6) {
            ForEach(nodes, id: \.symbol) { $0 }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Icons have no fixed width, so a narrow glyph like the bolt stays centred.
private struct PowerNode: View {
    let symbol: String
    let title: String
    let watts: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(watts.wattsText)
                .monospacedDigit()
        }
        .lineLimit(1)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 10))
        .help(title)
    }
}
