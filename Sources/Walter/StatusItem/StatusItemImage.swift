import AppKit

/// The menu bar icon and optional temperature, drawn as one image. It's a template image
/// unless a coloured warning dot is shown, in which case it's drawn in the menu bar's text colour.
enum StatusItemImage {
    struct Label: Equatable {
        let symbol: String
        let text: String?
        let warningColor: NSColor?
    }

    private static let spacing: CGFloat = 3
    private static let dotDiameter: CGFloat = 5

    static func make(_ label: Label) -> NSImage? {
        let font = NSFont.menuBarFont(ofSize: 0)
        // Dynamic colours resolve when the menu bar draws the image, so they follow its appearance.
        let ink = label.warningColor == nil ? NSColor.black : NSColor.labelColor
        let configuration = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .regular)
            .applying(.init(paletteColors: [ink]))
        guard let icon = NSImage(systemSymbolName: label.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }

        let title = label.text.map { NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: ink]) }
        let titleSize = title?.size() ?? .zero
        // The dot sits at the icon's top-right corner, so it needs room before the text.
        let dotSpace = label.warningColor == nil ? 0 : dotDiameter
        let gap = (title == nil ? 0 : spacing) + dotSpace
        let size = NSSize(width: ceil(icon.size.width + gap + titleSize.width),
                          height: ceil(max(icon.size.height, titleSize.height)))

        let image = NSImage(size: size, flipped: false) { rect in
            icon.draw(in: NSRect(x: 0, y: (rect.height - icon.size.height) / 2, width: icon.size.width, height: icon.size.height))
            title?.draw(at: NSPoint(x: icon.size.width + gap, y: (rect.height - titleSize.height) / 2))
            if let color = label.warningColor {
                let center = NSPoint(x: icon.size.width + dotDiameter / 2, y: rect.height - dotDiameter / 2)
                color.setFill()
                NSBezierPath(ovalIn: NSRect(x: center.x - dotDiameter / 2, y: center.y - dotDiameter / 2,
                                            width: dotDiameter, height: dotDiameter)).fill()
            }
            return true
        }
        let trimmed = trimmedHorizontally(image) ?? image
        trimmed.isTemplate = label.warningColor == nil
        return trimmed
    }

    /// Crops the symbol's built-in side margins and the text's trailing advance so the item is
    /// only as wide as its visible pixels.
    private static func trimmedHorizontally(_ image: NSImage) -> NSImage? {
        let scale: CGFloat = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * scale), pixelsHigh: Int(image.size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let inkColumns = (0..<bitmap.pixelsWide).filter { x in
            (0..<bitmap.pixelsHigh).contains { y in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 }
        }
        guard let first = inkColumns.first, let last = inkColumns.last else { return nil }

        let left = CGFloat(first) / scale
        let width = CGFloat(last - first + 1) / scale
        let trimmed = NSImage(size: NSSize(width: ceil(width), height: image.size.height), flipped: false) { rect in
            image.draw(at: NSPoint(x: -left, y: 0), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        return trimmed
    }
}
