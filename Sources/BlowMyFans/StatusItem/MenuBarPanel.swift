import AppKit
import Observation
import SwiftUI

/// SwiftUI draws the panel in a transparent window that fits it with room for its shadow. The window grows
/// before the panel animates to a larger size and shrinks after it animates to a smaller one, so the
/// panel is never cut off. A panel taller than `maximumPanelHeight` scrolls.
final class MenuBarPanel: NSPanel {
    static let animationDuration = 0.2
    static let shadowMargin: CGFloat = 24
    fileprivate static let cornerRadius: CGFloat = 22

    var onClose: (() -> Void)?
    /// How tall the panel may be on its screen; set before it's shown.
    var maximumPanelHeight: CGFloat {
        get { presence.maximumHeight }
        set {
            if newValue != presence.maximumHeight { presence.maximumHeight = newValue }
        }
    }
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

        let panel = FittedToScreen(presence: presence, content: rootView)
            .glassEffect(.regular, in: .rect(cornerRadius: Self.cornerRadius))
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
    var maximumHeight = CGFloat.infinity
}

/// The content as it is while it fits the screen, and in a scroll view once it doesn't, e.g. with
/// every sensor chosen on a small display, so the footer stays within reach.
private struct FittedToScreen<Content: View>: View {
    let presence: Presence
    let content: Content

    var body: some View {
        HeightLimit(maximum: presence.maximumHeight) {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
                    .clipShape(.rect(cornerRadius: MenuBarPanel.cornerRadius))
            }
        }
    }
}

/// Offers its content at most `maximum` in height, whatever it is offered itself.
private struct HeightLimit: Layout {
    var maximum: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: maximum)) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// Drops the content while the panel is hidden, so its animations and updates stop.
private struct OnScreen<Content: View>: View {
    let presence: Presence
    let content: Content

    var body: some View {
        if presence.isOnScreen { content }
    }
}
