// Renders Walter's app icon into Support/AppIcon.icns, plus a 1024 px preview PNG in the temp directory.
// Usage: swift scripts/make-icon.swift
import AppKit
import SwiftUI

let canvas: CGFloat = 1024
/// macOS icon grid: an 824 pt rounded square with a 100 pt margin, where macOS draws the shadow.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)

/// The system's icon shape. macOS 26 shows icons that don't fill it inside a grey tile.
func tileShape() -> CGPath {
    RoundedRectangle(cornerRadius: 185.4, style: .continuous).path(in: tile).cgPath
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

func polar(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
    CGPoint(x: radius * cos(angle), y: radius * sin(angle))
}

/// Ring of thin curved blades like a MacBook's blower fan, centred on the origin.
func impeller(inner: CGFloat, outer: CGFloat, count: Int, thickness: CGFloat) -> CGPath {
    let curves = CGMutablePath()
    for index in 0..<count {
        let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
        curves.move(to: polar(inner, angle))
        curves.addQuadCurve(to: polar(outer, angle - 0.42), control: polar((inner + outer) / 2 + 20, angle - 0.06))
    }
    return curves.copy(strokingWithWidth: thickness, lineCap: .round, lineJoin: .round, miterLimit: 1)
}

func render() -> CGImage {
    let context = CGContext(data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let shape = tileShape()

    // Background: bright blue at the top deepening to indigo, with a soft top light.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.drawLinearGradient(gradient([color(0x3fa2ff), color(0x1f5fe8), color(0x2a2fa8)], [0, 0.5, 1]),
                               start: CGPoint(x: tile.midX, y: tile.maxY), end: CGPoint(x: tile.midX, y: tile.minY),
                               options: [])
    context.drawRadialGradient(gradient([color(0xffffff, 0.25), color(0xffffff, 0)], [0, 1]),
                               startCenter: CGPoint(x: tile.midX, y: tile.maxY + 60), startRadius: 0,
                               endCenter: CGPoint(x: tile.midX, y: tile.maxY + 60), endRadius: 600, options: [])

    let center = CGPoint(x: tile.midX, y: tile.midY)
    let outer: CGFloat = 300
    let hub: CGFloat = 118
    context.translateBy(x: center.x, y: center.y)

    // Housing: a faint recessed disc behind the blades.
    context.setFillColor(color(0x001050, 0.18))
    context.fillEllipse(in: CGRect(x: -outer - 22, y: -outer - 22, width: 2 * outer + 44, height: 2 * outer + 44))

    // Blades and hub in one layer so they share a shadow and gradient.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x000a40, 0.4))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setFillColor(color(0xffffff))
    context.addPath(impeller(inner: hub - 30, outer: outer, count: 23, thickness: 15))
    context.fillPath()
    context.fillEllipse(in: CGRect(x: -hub, y: -hub, width: 2 * hub, height: 2 * hub))
    context.setBlendMode(.sourceAtop)
    context.drawLinearGradient(gradient([color(0xffffff), color(0xdbe8ff)], [0, 1]),
                               start: CGPoint(x: 0, y: outer), end: CGPoint(x: 0, y: -outer), options: [])
    context.endTransparencyLayer()
    context.restoreGState()

    // Hub cap.
    context.drawRadialGradient(gradient([color(0xffffff), color(0xe4eeff)], [0, 1]),
                               startCenter: CGPoint(x: -20, y: 30), startRadius: 0,
                               endCenter: .zero, endRadius: hub * 0.62, options: [])
    context.setStrokeColor(color(0x1f5fe8, 0.25))
    context.setLineWidth(5)
    context.strokeEllipse(in: CGRect(x: -hub * 0.62, y: -hub * 0.62, width: hub * 1.24, height: hub * 1.24))
    context.restoreGState()

    return context.makeImage()!
}

func png(_ image: CGImage, size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.cgContext.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let image = render()
for points in [16, 32, 128, 256, 512] {
    try png(image, size: points).write(to: iconset.appending(path: "icon_\(points)x\(points).png"))
    try png(image, size: points * 2).write(to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}
let output = root.appending(path: "Support/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(filePath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
let preview = FileManager.default.temporaryDirectory.appending(path: "AppIcon-preview.png")
try png(image, size: 1024).write(to: preview)
print("Wrote \(output.path) (preview: \(preview.path))")
