import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(FanController.self) private var controller

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
                Picker("Temperature unit", selection: $settings.useFahrenheit) {
                    Text("Celsius").tag(false)
                    Text("Fahrenheit").tag(true)
                }
                Picker("Menu bar shows", selection: $settings.menuBarItem) {
                    Text("Icon only").tag(AppSettings.iconOnly)
                    SensorChoices()
                }
            }

            Section {
                Toggle("Allow turning fans off", isOn: $settings.allowFanOff)
            } header: {
                Text("Manual Mode")
            } footer: {
                Text("Lets the slider go below a fan's minimum to stop it. Only use this while the Mac is idle.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Status") {
                    switch controller.helperStatus {
                    case .installed:
                        HStack {
                            Text("Installed")
                            Button("Uninstall") { Task { await controller.uninstallHelper() } }
                        }
                    case .notInstalled:
                        HStack {
                            Text("Not installed")
                            Button("Install") { Task { await controller.installHelper() } }
                        }
                    case .installing, .unknown:
                        ProgressView().controlSize(.small)
                    }
                }
            } header: {
                Text("Helper")
            } footer: {
                Text("A small background service that changes fan speeds. It hands fans back to macOS when the app quits.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 460)
    }
}

/// Picker options: the hottest CPU reading, then every sensor group on this Mac.
private struct SensorChoices: View {
    @Environment(HardwareMonitor.self) private var monitor

    var body: some View {
        Text("Hottest CPU").tag(AppSettings.hottestCPU)
        Divider()
        ForEach(monitor.availableGroups) { group in
            Text(group.name).tag(group.id)
        }
    }
}
