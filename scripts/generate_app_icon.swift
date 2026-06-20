#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let packagingURL = rootURL.appendingPathComponent("Packaging", isDirectory: true)
let iconsetURL = packagingURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let previewURL = rootURL
    .appendingPathComponent("docs", isDirectory: true)
    .appendingPathComponent("assets", isDirectory: true)
    .appendingPathComponent("app-icon.png")

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func scaled(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
    value * scale
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func oval(_ rect: NSRect) -> NSBezierPath {
    NSBezierPath(ovalIn: rect)
}

func drawRotatedOval(rect: NSRect, degrees: CGFloat, fill: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: degrees)
    transform.translateX(by: -rect.midX, yBy: -rect.midY)
    transform.concat()
    fill.setFill()
    oval(rect).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func drawIconPNGData(size: CGFloat) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap"])
    }

    bitmap.size = NSSize(width: size, height: size)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "AppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context"])
    }

    let s = size / 1024

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.setShouldAntialias(true)
    context.cgContext.setAllowsAntialiasing(true)
    defer { NSGraphicsContext.restoreGraphicsState() }

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let canvas = NSRect(x: scaled(54, s), y: scaled(54, s), width: scaled(916, s), height: scaled(916, s))
    let background = roundedRect(canvas, radius: scaled(210, s))

    let backgroundShadow = NSShadow()
    backgroundShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    backgroundShadow.shadowBlurRadius = scaled(34, s)
    backgroundShadow.shadowOffset = NSSize(width: 0, height: -scaled(16, s))
    backgroundShadow.set()

    color(253, 216, 230).setFill()
    background.fill()
    NSShadow().set()

    NSGraphicsContext.saveGraphicsState()
    background.addClip()
    NSGradient(colors: [
        color(255, 224, 235),
        color(231, 247, 244),
        color(218, 226, 255)
    ])?.draw(in: canvas, angle: 38)

    color(255, 255, 255, 0.28).setFill()
    oval(NSRect(x: scaled(112, s), y: scaled(672, s), width: scaled(310, s), height: scaled(210, s))).fill()
    color(131, 219, 206, 0.20).setFill()
    oval(NSRect(x: scaled(620, s), y: scaled(120, s), width: scaled(260, s), height: scaled(230, s))).fill()
    NSGraphicsContext.restoreGraphicsState()

    let petShadow = NSShadow()
    petShadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
    petShadow.shadowBlurRadius = scaled(26, s)
    petShadow.shadowOffset = NSSize(width: 0, height: -scaled(10, s))
    petShadow.set()

    color(236, 207, 220, 0.55).setFill()
    oval(NSRect(x: scaled(273, s), y: scaled(202, s), width: scaled(430, s), height: scaled(70, s))).fill()
    NSShadow().set()

    drawRotatedOval(
        rect: NSRect(x: scaled(293, s), y: scaled(559, s), width: scaled(152, s), height: scaled(300, s)),
        degrees: -14,
        fill: color(255, 255, 255)
    )
    drawRotatedOval(
        rect: NSRect(x: scaled(562, s), y: scaled(559, s), width: scaled(152, s), height: scaled(300, s)),
        degrees: 14,
        fill: color(255, 255, 255)
    )
    drawRotatedOval(
        rect: NSRect(x: scaled(330, s), y: scaled(605, s), width: scaled(78, s), height: scaled(206, s)),
        degrees: -14,
        fill: color(255, 184, 205)
    )
    drawRotatedOval(
        rect: NSRect(x: scaled(598, s), y: scaled(605, s), width: scaled(78, s), height: scaled(206, s)),
        degrees: 14,
        fill: color(255, 184, 205)
    )

    let faceShadow = NSShadow()
    faceShadow.shadowColor = NSColor.black.withAlphaComponent(0.13)
    faceShadow.shadowBlurRadius = scaled(24, s)
    faceShadow.shadowOffset = NSSize(width: 0, height: -scaled(10, s))
    faceShadow.set()
    color(255, 255, 255).setFill()
    roundedRect(NSRect(x: scaled(240, s), y: scaled(260, s), width: scaled(544, s), height: scaled(420, s)), radius: scaled(190, s)).fill()
    NSShadow().set()

    color(51, 43, 54).setFill()
    oval(NSRect(x: scaled(385, s), y: scaled(452, s), width: scaled(48, s), height: scaled(62, s))).fill()
    oval(NSRect(x: scaled(591, s), y: scaled(452, s), width: scaled(48, s), height: scaled(62, s))).fill()

    color(255, 255, 255, 0.85).setFill()
    oval(NSRect(x: scaled(405, s), y: scaled(488, s), width: scaled(16, s), height: scaled(18, s))).fill()
    oval(NSRect(x: scaled(611, s), y: scaled(488, s), width: scaled(16, s), height: scaled(18, s))).fill()

    color(255, 169, 194, 0.56).setFill()
    oval(NSRect(x: scaled(313, s), y: scaled(378, s), width: scaled(96, s), height: scaled(52, s))).fill()
    oval(NSRect(x: scaled(615, s), y: scaled(378, s), width: scaled(96, s), height: scaled(52, s))).fill()

    color(255, 130, 160).setFill()
    let nose = NSBezierPath()
    nose.move(to: NSPoint(x: scaled(512, s), y: scaled(421, s)))
    nose.line(to: NSPoint(x: scaled(535, s), y: scaled(450, s)))
    nose.line(to: NSPoint(x: scaled(489, s), y: scaled(450, s)))
    nose.close()
    nose.fill()

    color(122, 72, 90).setStroke()
    let mouth = NSBezierPath()
    mouth.lineWidth = scaled(8, s)
    mouth.move(to: NSPoint(x: scaled(512, s), y: scaled(418, s)))
    mouth.curve(
        to: NSPoint(x: scaled(468, s), y: scaled(390, s)),
        controlPoint1: NSPoint(x: scaled(504, s), y: scaled(398, s)),
        controlPoint2: NSPoint(x: scaled(486, s), y: scaled(390, s))
    )
    mouth.move(to: NSPoint(x: scaled(512, s), y: scaled(418, s)))
    mouth.curve(
        to: NSPoint(x: scaled(556, s), y: scaled(390, s)),
        controlPoint1: NSPoint(x: scaled(520, s), y: scaled(398, s)),
        controlPoint2: NSPoint(x: scaled(538, s), y: scaled(390, s))
    )
    mouth.stroke()

    let bubbleShadow = NSShadow()
    bubbleShadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
    bubbleShadow.shadowBlurRadius = scaled(18, s)
    bubbleShadow.shadowOffset = NSSize(width: 0, height: -scaled(8, s))
    bubbleShadow.set()

    color(255, 255, 255, 0.98).setFill()
    roundedRect(NSRect(x: scaled(620, s), y: scaled(574, s), width: scaled(268, s), height: scaled(180, s)), radius: scaled(58, s)).fill()
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: scaled(662, s), y: scaled(583, s)))
    tail.line(to: NSPoint(x: scaled(602, s), y: scaled(528, s)))
    tail.line(to: NSPoint(x: scaled(728, s), y: scaled(575, s)))
    tail.close()
    tail.fill()
    NSShadow().set()

    [color(255, 124, 154), color(130, 211, 198), color(143, 156, 244)].enumerated().forEach { index, dotColor in
        dotColor.setFill()
        oval(NSRect(x: scaled(682 + CGFloat(index) * 58, s), y: scaled(645, s), width: scaled(34, s), height: scaled(34, s))).fill()
    }

    color(255, 77, 109).setFill()
    oval(NSRect(x: scaled(832, s), y: scaled(725, s), width: scaled(72, s), height: scaled(72, s))).fill()
    color(255, 255, 255, 0.86).setFill()
    oval(NSRect(x: scaled(850, s), y: scaled(764, s), width: scaled(18, s), height: scaled(18, s))).fill()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }

    return data
}

func writePNG(size: CGFloat, to url: URL) throws {
    try drawIconPNGData(size: size).write(to: url)
}

let iconFiles: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconFiles {
    try writePNG(size: size, to: iconsetURL.appendingPathComponent(name))
}

try writePNG(size: 512, to: previewURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    "-o", packagingURL.appendingPathComponent("AppIcon.icns").path,
    iconsetURL.path
]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "AppIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Generated Packaging/AppIcon.icns and docs/assets/app-icon.png")
