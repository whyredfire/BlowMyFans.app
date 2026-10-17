import AppKit

/// The menu bar icon and optional temperature, drawn as one template image.
enum StatusItemImage {
    struct Label: Equatable {
        let symbol: String
        let text: String?
    }

    private static let spacing: CGFloat = 3

    static func make(_ label: Label) -> NSImage? {
        let font = NSFont.menuBarFont(ofSize: 0)
        let configuration = NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .regular)
        guard let icon = NSImage(systemSymbolName: label.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }

        let title = label.text.map { NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: NSColor.black]) }
        let titleSize = title?.size() ?? .zero
        let gap = title == nil ? 0 : spacing
        let size = NSSize(width: ceil(icon.size.width + gap + titleSize.width),
                          height: ceil(max(icon.size.height, titleSize.height)))

        let image = NSImage(size: size, flipped: false) { rect in
            icon.draw(in: NSRect(x: 0, y: (rect.height - icon.size.height) / 2, width: icon.size.width, height: icon.size.height))
            title?.draw(at: NSPoint(x: icon.size.width + gap, y: (rect.height - titleSize.height) / 2))
            return true
        }
        return trimmedHorizontally(image) ?? image
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
        trimmed.isTemplate = true
        return trimmed
    }
}
