import SwiftUI

/// A stack at least `minimumWidth` wide, widened only by views marked `setsPanelWidth()`, such as the
/// segmented picker, which macOS 27 won't shrink below four times its widest label.
struct PanelStack: Layout {
    var minimumWidth: CGFloat
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = width(of: subviews)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }

    private func width(of subviews: Subviews) -> CGFloat {
        subviews.filter { $0[SetsWidth.self] }.map { $0.sizeThatFits(.unspecified).width }.reduce(minimumWidth, max)
    }

    struct SetsWidth: LayoutValueKey {
        static let defaultValue = false
    }
}

extension View {
    func setsPanelWidth() -> some View {
        layoutValue(key: PanelStack.SetsWidth.self, value: true)
    }
}
