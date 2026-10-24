import AppKit

let destination = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)

func drawIcon(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
    NSGradient(starting: NSColor(srgbRed: 0.29, green: 0.63, blue: 1, alpha: 1),
               ending: NSColor(srgbRed: 0.05, green: 0.33, blue: 0.86, alpha: 1))!.draw(in: background, angle: -90)
    NSColor.white.withAlphaComponent(0.20).setStroke()
    let globe = NSBezierPath(ovalIn: NSRect(x: 238, y: 238, width: 548, height: 548))
    globe.lineWidth = 24
    globe.stroke()
    let meridian = NSBezierPath(ovalIn: NSRect(x: 376, y: 238, width: 272, height: 548))
    meridian.lineWidth = 21
    meridian.stroke()
    let equator = NSBezierPath()
    equator.move(to: NSPoint(x: 246, y: 512))
    equator.line(to: NSPoint(x: 778, y: 512))
    equator.lineWidth = 20
    equator.stroke()
    NSColor.white.setStroke()
    for top in [true, false] {
        let path = NSBezierPath()
        path.lineWidth = 61
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        if top {
            path.move(to: NSPoint(x: 292, y: 622)); path.line(to: NSPoint(x: 724, y: 622))
            path.move(to: NSPoint(x: 642, y: 704)); path.line(to: NSPoint(x: 724, y: 622)); path.line(to: NSPoint(x: 642, y: 540))
        } else {
            path.move(to: NSPoint(x: 732, y: 402)); path.line(to: NSPoint(x: 300, y: 402))
            path.move(to: NSPoint(x: 382, y: 484)); path.line(to: NSPoint(x: 300, y: 402)); path.line(to: NSPoint(x: 382, y: 320))
        }
        path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let data = try drawIcon(size: points * scale)
        try data.write(to: URL(fileURLWithPath: "\(destination)/icon_\(points)x\(points)\(suffix).png"))
    }
}
