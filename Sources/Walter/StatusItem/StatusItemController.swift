import AppKit
import Observation
import SwiftUI

/// Owns the menu bar item and the panel it opens.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: MenuBarPanel
    private let settings: AppSettings
    private let monitor: HardwareMonitor
    private let controller: FanController
    private var clickMonitor: Any?
    private var displayedLabel: StatusItemImage.Label?

    init(settings: AppSettings, monitor: HardwareMonitor, controller: FanController) {
        self.settings = settings
        self.monitor = monitor
        self.controller = controller
        panel = MenuBarPanel(rootView: MenuBarContent()
            .environment(settings)
            .environment(monitor)
            .environment(controller))
        super.init()

        panel.onClose = { [weak self] in self?.close() }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.positionPanel() }
        }

        if #available(macOS 27, *) {
            statusItem.expandedInterfaceDelegate = self
        } else {
            statusItem.button?.target = self
            statusItem.button?.action = #selector(toggle)
        }
        updateButton()
    }

    /// Redraws the item when the mode or displayed temperature changes.
    private func updateButton() {
        withObservationTracking {
            let temperature = settings.menuBarItem == AppSettings.iconOnly
                ? nil
                : monitor.temperatures.temperature(for: settings.menuBarItem).map(settings.format)
            let thermalState = monitor.thermalState
            let label = StatusItemImage.Label(symbol: controller.mode.symbol, text: temperature,
                                              warningColor: thermalState.warningColor)
            guard label != displayedLabel else { return }
            displayedLabel = label
            statusItem.button?.image = StatusItemImage.make(label)
            let pressure = thermalState == .nominal ? nil : "thermal pressure \(thermalState.title.lowercased())"
            statusItem.button?.setAccessibilityLabel(["Walter", temperature, pressure].compactMap(\.self).joined(separator: ", "))
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateButton() }
        }
    }

    // MARK: Panel

    @objc private func toggle() {
        panel.isVisible ? close() : open()
    }

    private func open() {
        monitor.isShowingDetails = true
        panel.prepareContent()
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    /// Closes on the user's behalf; on macOS 27 the menu bar ends the session, which hides the panel.
    private func close() {
        if #available(macOS 27, *), let session = statusItem.expandedInterfaceSession {
            session.cancel()
        } else {
            hidePanel()
        }
    }

    private func hidePanel() {
        monitor.isShowingDetails = false
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    private func positionPanel() {
        guard let itemFrame = statusItem.button?.window?.frame,
              let screen = statusItem.button?.window?.screen ?? NSScreen.main else { return }
        let size = panel.frame.size
        let visible = screen.visibleFrame
        let x = min(max(itemFrame.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: itemFrame.minY - size.height - 6))
    }
}

@available(macOS 27, *)
extension StatusItemController: @MainActor NSStatusItemExpandedInterfaceDelegate {
    func statusItem(_ statusItem: NSStatusItem, didBegin session: NSStatusItemExpandedInterfaceSession) {
        open()
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        hidePanel()
    }
}
