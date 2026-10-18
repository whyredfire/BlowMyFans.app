import SwiftUI

struct MenuBarContent: View {
    @Environment(FanController.self) private var controller
    @Environment(HardwareMonitor.self) private var monitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if monitor.fans.isEmpty {
                Text("This Mac has no fans to control.")
                    .foregroundStyle(.secondary)
            } else {
                ModePicker()
                    .controlSize(.large)
                ModeControls()
                StatusMessage()

                Divider()

                VStack(spacing: 12) {
                    ForEach(monitor.visibleFans) { FanRow(fan: $0) }
                }
            }

            Divider()

            VStack(spacing: 10) {
                ThermalPressureRow(state: monitor.thermalState)
                ForEach(monitor.temperatures.highlights.prefix(5)) { TemperatureRow(reading: $0) }
            }

            Divider()

            HStack {
                Button("Settings", systemImage: "gearshape") {
                    openSettings()
                    NSApp.activate()
                }
                Spacer()
                Button("Quit", systemImage: "power") { NSApp.terminate(nil) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(16)
        .frame(width: 340)
        .animation(.smooth, value: controller.mode)
    }
}
