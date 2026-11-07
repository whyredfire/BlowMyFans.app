import AppKit
import Observation
import SwiftUI

/// The window is transparent down to the bottom of the screen and SwiftUI draws the panel, so its size
/// animates without the window resizing, which makes the content jump.
final class MenuBarPanel: NSPanel {
    static let animationDuration = 0.2
    static let shadowMargin: CGFloat = 24

    var onClose: (() -> Void)?
    var placement: ((CGFloat) -> NSRect)?
    private let presence = Presence()
    private var panelWidth: CGFloat = 0

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
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { [weak self] width in
                DispatchQueue.main.async { self?.fit(width) }
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
        guard panelWidth > 0, let placement else { return }
        setFrame(placement(panelWidth), display: true)
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

    private func fit(_ width: CGFloat) {
        guard width > 0, width != panelWidth else { return }
        panelWidth = width
        place()
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
