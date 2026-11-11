import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Panel", systemImage: "menubar.rectangle") { PanelSettings() }
            Tab("Advanced", systemImage: "gearshape.2") { AdvancedSettings() }
        }
    }
}

private struct GeneralSettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PowerSourceMonitor.self) private var power

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
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
                Picker("Update every", selection: $settings.updateInterval) {
                    ForEach(AppSettings.updateIntervals, id: \.self) { seconds in
                        Text(Duration.seconds(seconds).formatted(.units(allowed: [.seconds], width: .wide))).tag(seconds)
                    }
                }
            } footer: {
                Text("How often the menu bar and panel update. Longer intervals use a little less energy. Curve mode checks the CPU temperature every 2 seconds regardless.")
                    .foregroundStyle(.secondary)
            }

            if power.hasBattery {
                PowerSection()
            }
        }
        .settingsPage()
        .onAppear { settings.refreshLaunchAtLogin() }
    }
}

private struct PanelSettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HardwareMonitor.self) private var monitor

    var body: some View {
        Form {
            Section {
                ForEach(PanelSection.allCases) { section in
                    Toggle(section.title, isOn: Binding(
                        get: { settings.shows(section) },
                        set: { settings.setShows(section, $0) }
                    ))
                }
            } header: {
                Text("Show in the panel")
            } footer: {
                if !settings.shows(.footer) {
                    Label("Without the footer, press ⌘, in the panel to open Settings and ⌘Q to quit.",
                          systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.shows(.temperatures) {
                Section {
                    Picker("Sensors", selection: Binding(
                        get: { settings.panelSensors == nil },
                        // Choosing starts from what the panel shows now.
                        set: { settings.panelSensors = $0 ? nil : monitor.availableGroups.panelDefaults.map(\.id) }
                    )) {
                        Text("Automatic").tag(true)
                        Text("Choose").tag(false)
                    }
                    if let chosen = settings.panelSensors {
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                                  alignment: .leading, spacing: 8) {
                            ForEach(monitor.availableGroups.highlights) { group in
                                Toggle(group.shortName, isOn: Binding(
                                    get: { chosen.contains(group.id) },
                                    set: { settings.panelSensors = $0 ? chosen + [group.id] : chosen.filter { $0 != group.id } }
                                ))
                                .toggleStyle(.checkbox)
                                .help(group.name)
                            }
                        }
                    }
                } header: {
                    Text("Temperatures")
                } footer: {
                    Text("Automatic lists the CPU, GPU, SSD and battery, then the next most useful sensor. Only the sensors shown are read.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .settingsPage()
    }
}

private struct AdvancedSettings: View {
    @Environment(FanController.self) private var controller
    @Environment(AppUpdater.self) private var updater

    var body: some View {
        @Bindable var updater = updater
        Form {
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

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
                LabeledContent("Version \(updater.version)") {
                    Button("Check for Updates…") { updater.checkForUpdates() }
                }
            }
        }
        .settingsPage()
    }
}

private extension View {
    /// As tall as its content, so each tab sizes the window.
    func settingsPage() -> some View {
        formStyle(.grouped)
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

/// A mode for each power source, switched when the Mac is plugged in or unplugged.
private struct PowerSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(FanController.self) private var controller

    var body: some View {
        Section {
            Toggle("Switch modes with power source", isOn: Binding(
                get: { settings.switchesModeWithPower },
                set: { controller.setSwitchesModeWithPower($0) }
            ))
            if settings.switchesModeWithPower {
                ForEach(PowerSource.allCases) { source in
                    Picker(source.title, selection: Binding(
                        get: { settings.mode(for: source) },
                        set: { controller.setMode($0, for: source) }
                    )) {
                        ForEach(FanMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
            }
        } header: {
            Text("Power")
        } footer: {
            Text("Applying a mode in the menu bar also sets it for the power source you're on.")
                .foregroundStyle(.secondary)
        }
    }
}
