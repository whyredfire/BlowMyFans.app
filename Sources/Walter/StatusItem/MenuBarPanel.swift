import AppKit
import Observation
import SwiftUI

/// Borderless glass panel shown beneath the status item, sized to its SwiftUI content.
final class MenuBarPanel: NSPanel {
    private static let cornerRadius: CGFloat = 22

    var onClose: (() -> Void)?
    private let presence = Presence()

    init(rootView: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        // Closing is handled by `resignKey`; AppKit hiding the panel itself would leave the item highlighted.
        hidesOnDeactivate = false
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // The content reports its size and the panel follows on the next run loop turn;
        // letting constraints resize the window mid-layout makes AppKit throw.
        let content = OnScreen(presence: presence, content: rootView)
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: \.size) { [weak self] size in
                DispatchQueue.main.async { self?.fit(size) }
            }
        let hostingView = NSHostingView(rootView: content)
        hostingView.sizingOptions = []
        hostingView.safeAreaRegions = []

        let glass = NSGlassEffectView()
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = hostingView

        // Clipping the content to the glass shape gives the window a matching rounded shadow.
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        glass.translatesAutoresizingMaskIntoConstraints = true
        glass.autoresizingMask = [.width, .height]
        container.addSubview(glass)
        contentView = container
    }

    override var canBecomeKey: Bool { true }

    /// Builds the content before the panel is shown, so it never appears empty.
    func prepareContent() {
        presence.isOnScreen = true
        contentView?.layoutSubtreeIfNeeded()
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        presence.isOnScreen = false
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        invalidateShadow()
    }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }

    /// Opening Settings or clicking elsewhere in the app dismisses the panel, like a menu.
    override func resignKey() {
        super.resignKey()
        onClose?()
    }

    private func fit(_ size: CGSize) {
        guard size.width > 0, size.height > 0, frame.size != size else { return }
        setContentSize(size)
        invalidateShadow()
    }
}

@MainActor @Observable
private final class Presence {
    var isOnScreen = false
}

/// Drops the content while the panel is hidden, so its animations and updates stop.
private struct OnScreen<Content: View>: View {
    let presence: Presence
    let content: Content

    var body: some View {
        if presence.isOnScreen { content }
    }
}
