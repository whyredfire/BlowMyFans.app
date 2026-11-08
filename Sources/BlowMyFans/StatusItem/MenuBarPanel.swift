import AppKit
import Observation
import SwiftUI

/// SwiftUI draws the panel in a transparent window that fits it with room for its shadow. The window grows
/// before the panel animates to a larger size and shrinks after it animates to a smaller one, so the
/// panel is never cut off.
final class MenuBarPanel: NSPanel {
    static let animationDuration = 0.2
    static let shadowMargin: CGFloat = 24

    var onClose: (() -> Void)?
    /// The window's frame for a panel of the given size.
    var placement: ((CGSize) -> NSRect)?
    private let presence = Presence()
    private var panelSize = CGSize.zero
    /// The panel height the window has room for, which lags `panelSize` while the panel shrinks.
    private var placedHeight: CGFloat = 0
    private var pendingShrink: DispatchWorkItem?

    init(rootView: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        // Closing is handled by `resignKey`; AppKit hiding the panel itself would leave the item highlighted.
        hidesOnDeactivate = false
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let panel = rootView
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        // Resizing the window mid-layout makes AppKit throw.
        let content = OnScreen(presence: presence, content: panel)
            .fixedSize()
            .onGeometryChange(for: CGSize.self, of: \.size) { [weak self] size in
                DispatchQueue.main.async { self?.fit(size) }
            }
            .padding([.horizontal, .bottom], Self.shadowMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        let hostingView = NSHostingView(rootView: content)
        hostingView.sizingOptions = []
        hostingView.safeAreaRegions = []
        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }

    /// Builds the content before the panel is shown, so it never appears empty.
    func prepareContent() {
        presence.isOnScreen = true
        contentView?.layoutSubtreeIfNeeded()
    }

    func place() {
        place(height: panelSize.height)
    }

    private func place(height: CGFloat) {
        guard panelSize.width > 0, let placement else { return }
        placedHeight = height
        setFrame(placement(CGSize(width: panelSize.width, height: height)), display: true)
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        presence.isOnScreen = false
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
        guard size.width > 0, size != panelSize else { return }
        panelSize = size
        pendingShrink?.cancel()
        guard isVisible, size.height < placedHeight else { return place() }
        place(height: placedHeight)
        let shrink = DispatchWorkItem { [weak self] in self?.place() }
        pendingShrink = shrink
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.animationDuration, execute: shrink)
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
