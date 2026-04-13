import Cocoa
import Foundation

// Generate app icon: shield with "IP" text

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size
    let pad = s * 0.08

    // Shield path
    let shieldPath = NSBezierPath()
    let cx = s / 2
    let topY = s - pad
    let bottomY = pad
    let midY = s * 0.35
    let sideX = pad
    let rightX = s - pad

    shieldPath.move(to: NSPoint(x: cx, y: topY))
    // Top-right curve
    shieldPath.curve(to: NSPoint(x: rightX, y: s * 0.7),
                     controlPoint1: NSPoint(x: cx + (rightX - cx) * 0.3, y: topY),
                     controlPoint2: NSPoint(x: rightX, y: s * 0.85))
    // Right side down
    shieldPath.curve(to: NSPoint(x: cx, y: bottomY),
                     controlPoint1: NSPoint(x: rightX, y: midY),
                     controlPoint2: NSPoint(x: cx + (rightX - cx) * 0.4, y: bottomY + s * 0.1))
    // Bottom to left
    shieldPath.curve(to: NSPoint(x: sideX, y: s * 0.7),
                     controlPoint1: NSPoint(x: cx - (cx - sideX) * 0.4, y: bottomY + s * 0.1),
                     controlPoint2: NSPoint(x: sideX, y: midY))
    // Left side up to top
    shieldPath.curve(to: NSPoint(x: cx, y: topY),
                     controlPoint1: NSPoint(x: sideX, y: s * 0.85),
                     controlPoint2: NSPoint(x: cx - (cx - sideX) * 0.3, y: topY))
    shieldPath.close()

    // Shadow
    ctx.saveGState()
    let shadowColor = NSColor.black.withAlphaComponent(0.3).cgColor
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.05, color: shadowColor)

    // Shield gradient fill
    let gradient = NSGradient(colors: [
        NSColor(red: 0.18, green: 0.75, blue: 0.45, alpha: 1.0),  // bright green
        NSColor(red: 0.10, green: 0.55, blue: 0.35, alpha: 1.0),  // darker green
    ])!
    gradient.draw(in: shieldPath, angle: 90)
    ctx.restoreGState()

    // Shield border
    NSColor(red: 0.08, green: 0.45, blue: 0.28, alpha: 1.0).setStroke()
    shieldPath.lineWidth = s * 0.02
    shieldPath.stroke()

    // Inner highlight
    let innerPath = NSBezierPath()
    let inset = s * 0.06
    let innerCx = cx
    let innerTopY = topY - inset
    let innerBottomY = bottomY + inset * 1.5
    let innerSideX = sideX + inset
    let innerRightX = rightX - inset

    innerPath.move(to: NSPoint(x: innerCx, y: innerTopY))
    innerPath.curve(to: NSPoint(x: innerRightX, y: s * 0.68),
                    controlPoint1: NSPoint(x: innerCx + (innerRightX - innerCx) * 0.3, y: innerTopY),
                    controlPoint2: NSPoint(x: innerRightX, y: s * 0.82))
    innerPath.curve(to: NSPoint(x: innerCx, y: innerBottomY),
                    controlPoint1: NSPoint(x: innerRightX, y: midY + inset * 0.3),
                    controlPoint2: NSPoint(x: innerCx + (innerRightX - innerCx) * 0.35, y: innerBottomY + s * 0.08))
    innerPath.curve(to: NSPoint(x: innerSideX, y: s * 0.68),
                    controlPoint1: NSPoint(x: innerCx - (innerCx - innerSideX) * 0.35, y: innerBottomY + s * 0.08),
                    controlPoint2: NSPoint(x: innerSideX, y: midY + inset * 0.3))
    innerPath.curve(to: NSPoint(x: innerCx, y: innerTopY),
                    controlPoint1: NSPoint(x: innerSideX, y: s * 0.82),
                    controlPoint2: NSPoint(x: innerCx - (innerCx - innerSideX) * 0.3, y: innerTopY))
    innerPath.close()

    NSColor.white.withAlphaComponent(0.12).setStroke()
    innerPath.lineWidth = s * 0.01
    innerPath.stroke()

    // "IP" text
    let fontSize = s * 0.32
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let text = "IP" as NSString
    let textSize = text.size(withAttributes: textAttrs)
    let textX = (s - textSize.width) / 2
    let textY = (s - textSize.height) / 2 - s * 0.02
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttrs)

    // Small checkmark below text
    let checkPath = NSBezierPath()
    let checkCx = cx
    let checkY = textY - s * 0.04
    let checkSize = s * 0.08
    checkPath.move(to: NSPoint(x: checkCx - checkSize, y: checkY))
    checkPath.line(to: NSPoint(x: checkCx - checkSize * 0.2, y: checkY - checkSize * 0.7))
    checkPath.line(to: NSPoint(x: checkCx + checkSize * 1.1, y: checkY + checkSize * 0.5))
    NSColor.white.withAlphaComponent(0.9).setStroke()
    checkPath.lineWidth = s * 0.025
    checkPath.lineCapStyle = .round
    checkPath.lineJoinStyle = .round
    checkPath.stroke()

    image.unlockFocus()
    return image
}

func saveAsPNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

// Generate iconset
let iconsetPath = NSTemporaryDirectory() + "IPinsideMock.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, size) in sizes {
    let icon = createIcon(size: size)
    saveAsPNG(icon, to: "\(iconsetPath)/\(name).png")
}

print("Iconset generated at: \(iconsetPath)")

// Convert to .icns
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
let outputPath = NSHomeDirectory() + "/ipinside-mock/AppIcon.icns"
process.arguments = ["-c", "icns", iconsetPath, "-o", outputPath]
try! process.run()
process.waitUntilExit()
print("Icon saved to: \(outputPath)")
