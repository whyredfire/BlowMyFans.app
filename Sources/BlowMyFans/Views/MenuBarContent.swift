import SwiftUI

struct MenuBarContent: View {
    @Environment(FanController.self) private var controller
    @Environment(HardwareMonitor.self) private var monitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // 340 pt with the padding, wider if the mode picker or footer buttons need it.
        PanelStack(minimumWidth: 308, spacing: 14) {
            if monitor.fans.isEmpty {
                Text("This Mac has no fans to control.")
                    .foregroundStyle(.secondary)
            } else {
                ModePicker()
                    .controlSize(.large)
                    .setsPanelWidth()
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
                ForEach(monitor.panelTemperatures) { TemperatureRow(reading: $0) }
            }

            Divider()

            HStack {
                Button("Settings", systemImage: "gearshape") {
                    openSettings()
                    NSApp.activate()
                }
                Spacer()
                ApplyButtons()
                Spacer()
                Button("Quit", systemImage: "power") { NSApp.terminate(nil) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
            .setsPanelWidth()
        }
        .padding(16)
        .animation(.smooth, value: controller.draft.mode)
        .animation(.smooth, value: controller.hasUnappliedChanges)
    }
}
