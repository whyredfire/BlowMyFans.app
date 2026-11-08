import SwiftUI

struct MenuBarContent: View {
    @Environment(AppSettings.self) private var settings
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

                if settings.shows(.fans) {
                    Divider()
                    VStack(spacing: 12) {
                        ForEach(monitor.visibleFans) { FanRow(fan: $0) }
                    }
                }
            }

            if settings.shows(.power), let power = monitor.power {
                Divider()
                PowerFlowRow(flow: power)
            }

            let temperatures = monitor.panelTemperatures
            if settings.shows(.thermalPressure) || !temperatures.isEmpty {
                Divider()
                VStack(spacing: 10) {
                    if settings.shows(.thermalPressure) {
                        ThermalPressureRow(state: monitor.thermalState)
                    }
                    ForEach(temperatures) { TemperatureRow(reading: $0) }
                }
            }

            if settings.shows(.footer) {
                Divider()
                HStack {
                    Button("Settings", systemImage: "gearshape", action: showSettings)
                        .footerIcon()
                        .keyboardShortcut(",")
                    Spacer()
                    ApplyButtons()
                        .buttonBorderShape(.capsule)
                    Spacer()
                    Button("Quit", systemImage: "power", action: quit)
                        .footerIcon()
                        .keyboardShortcut("q")
                }
                .setsPanelWidth()
            } else if controller.hasUnappliedChanges {
                Divider()
                HStack {
                    ApplyButtons()
                        .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(16)
        .background {
            // The footer's shortcuts, kept while it's hidden.
            if !settings.shows(.footer) {
                Group {
                    Button("Settings", action: showSettings).keyboardShortcut(",")
                    Button("Quit", action: quit).keyboardShortcut("q")
                }
                .opacity(0)
                .accessibilityHidden(true)
            }
        }
        .animation(.easeInOut(duration: MenuBarPanel.animationDuration), value: controller.draft.mode)
        .animation(.easeInOut(duration: MenuBarPanel.animationDuration), value: controller.hasUnappliedChanges)
    }

    private func showSettings() {
        openSettings()
        NSApp.activate()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

private extension View {
    func footerIcon() -> some View {
        labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
    }
}
