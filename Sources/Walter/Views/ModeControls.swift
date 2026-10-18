import SMCKit
import SwiftUI

struct ModePicker: View {
    @Environment(FanController.self) private var controller

    var body: some View {
        Picker("Mode", selection: Binding(get: { controller.mode }, set: { controller.select($0) })) {
            ForEach(FanMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }
}

struct ModeControls: View {
    @Environment(FanController.self) private var controller

    var body: some View {
        switch controller.mode {
        case .manual: ManualControls()
        case .curve: FanCurveEditor()
        case .automatic, .fullBlast: EmptyView()
        }
    }
}

private struct ManualControls: View {
    @Environment(FanController.self) private var controller
    @Environment(HardwareMonitor.self) private var monitor

    var body: some View {
        @Bindable var controller = controller
        if let range = monitor.fanSpeedRange {
            SpeedSlider(title: monitor.visibleFans.count > 1 ? "All fans" : "Speed",
                        value: $controller.configuration.manual.rpm, range: range)
        } else {
            UnavailableRange()
        }
    }
}

private struct UnavailableRange: View {
    var body: some View {
        Text("Fan speed range unavailable")
            .foregroundStyle(.secondary)
    }
}

private struct SpeedSlider: View {
    @Environment(AppSettings.self) private var settings
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: value))
            }
            // Snaps in the binding instead of using `step:`, which draws a tick mark per step
            // and makes the slider wider than the popover.
            Slider(value: Binding(get: { max(value, start) }, set: { setSliderValue($0) }),
                   in: start...range.upperBound)
                .labelsHidden()
        }
    }

    /// With fans allowed off, "Off" is one notch below the minimum rather than everything from 0 up to it.
    private var start: Double {
        settings.allowFanOff ? range.lowerBound - (range.upperBound - range.lowerBound) * 0.05 : range.lowerBound
    }

    private func setSliderValue(_ position: Double) {
        if settings.allowFanOff, position < (start + range.lowerBound) / 2 {
            value = 0
        } else {
            value = min(max((position / 50).rounded() * 50, range.lowerBound), range.upperBound)
        }
    }

    private var valueText: String {
        if value < range.lowerBound {
            return settings.allowFanOff ? "Off" : range.lowerBound.rpmText
        }
        return min(value, range.upperBound).rpmText
    }
}
