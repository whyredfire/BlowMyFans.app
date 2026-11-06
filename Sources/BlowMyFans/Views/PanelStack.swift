import SwiftUI

/// A leading-aligned vertical stack at least `minimumWidth` wide, and wider only when a control that
/// can't shrink needs it, e.g. a segmented picker, which macOS sizes to four times its widest label.
/// Everything else, wrapping text included, is laid out at that width rather than widening it.
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
    /// Lets this view widen a `PanelStack` to its natural width.
    func setsPanelWidth() -> some View {
        layoutValue(key: PanelStack.SetsWidth.self, value: true)
    }
}
