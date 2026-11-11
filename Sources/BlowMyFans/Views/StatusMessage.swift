import SwiftUI

/// Helper installation progress, the latest error with a way to resume a paused mode, or why the
/// fans aren't at the speed that was asked for.
struct StatusMessage: View {
    @Environment(FanController.self) private var controller
    @Environment(HardwareMonitor.self) private var monitor

    var body: some View {
        Group {
            if controller.helperStatus == .installing {
                Label("Installing helper…", systemImage: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            } else if let message = controller.errorMessage ?? monitor.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    if controller.isSuspended {
                        Button(controller.helperStatus == .installed ? String(localized: "Resume \(controller.mode.title)") : String(localized: "Install Helper & Resume")) {
                            controller.retry()
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                    }
                }
            } else if controller.isCoolingDown {
                Label("Your Mac is too hot, so the fans are at full speed until it cools down.", systemImage: "thermometer.high")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.callout)
    }
}
