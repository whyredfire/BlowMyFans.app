import SwiftUI

/// Helper installation progress, or the latest error with a way to resume a paused mode.
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
            }
        }
        .font(.callout)
    }
}
