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
        image.isTemplate = label.warningColor == nil
        return trimmedHorizontally(image, isTemplate: image.isTemplate) ?? image
    }

    /// Crops the symbol's built-in side margins and the text's trailing advance so the item is
    /// only as wide as its visible pixels.
    private static func trimmedHorizontally(_ image: NSImage, isTemplate: Bool) -> NSImage? {
        let scale = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(image.size.width) * scale, pixelsHigh: Int(image.size.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let pixels = bitmap.bitmapData else { return nil }
        bitmap.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let rowBytes = bitmap.bytesPerRow
        func isInked(_ x: Int) -> Bool {
            (0..<bitmap.pixelsHigh).contains { y in pixels[y * rowBytes + x * 4 + 3] > 12 }
        }
        guard let first = (0..<bitmap.pixelsWide).first(where: isInked),
              let last = (0..<bitmap.pixelsWide).last(where: isInked) else { return nil }
        let width = ceil(CGFloat(last - first + 1) / CGFloat(scale))
        let size = NSSize(width: width, height: image.size.height)

        if isTemplate {
            // Template images only use alpha, so the menu bar can draw these pixels as they are
            // instead of rendering the symbol and text again on every redraw.
            let crop = CGRect(x: first, y: 0, width: min(Int(width) * scale, bitmap.pixelsWide - first), height: bitmap.pixelsHigh)
            guard let cropped = bitmap.cgImage?.cropping(to: crop) else { return nil }
            let trimmed = NSImage(cgImage: cropped, size: size)
            trimmed.isTemplate = true
            return trimmed
        }
        // Dynamic colours resolve when the menu bar draws, so this stays vector.
        let left = CGFloat(first) / CGFloat(scale)
        return NSImage(size: size, flipped: false) { _ in
            image.draw(at: NSPoint(x: -left, y: 0), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
    }
}
