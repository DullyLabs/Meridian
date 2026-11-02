// Draws the Meridian icon (four sky tiles: dawn, day, dusk, night) as an .iconset at the path given.
import AppKit

func color(_ r: Double, _ g: Double, _ b: Double) -> NSColor { NSColor(red: r, green: g, blue: b, alpha: 1) }

let skies: [(NSColor, NSColor)] = [
    (color(0.98, 0.62, 0.42), color(0.45, 0.36, 0.70)), (color(0.35, 0.70, 1.00), color(0.13, 0.45, 0.88)),
    (color(0.10, 0.12, 0.30), color(0.03, 0.04, 0.12)), (color(0.95, 0.45, 0.35), color(0.30, 0.18, 0.48)),
]

func draw(_ size: Double) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let s = size / 1024
        let tile = NSBezierPath(roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s), xRadius: 185 * s, yRadius: 185 * s)
        NSGradient(starting: color(0.16, 0.17, 0.22), ending: color(0.06, 0.06, 0.09))!.draw(in: tile, angle: -90)
        for (i, sky) in skies.enumerated() {
            let x = (166 + Double(i % 2) * 356) * s, y = (522 - Double(i / 2) * 356) * s
            let rect = NSRect(x: x, y: y, width: 336 * s, height: 336 * s)
            NSGradient(starting: sky.0, ending: sky.1)!.draw(in: NSBezierPath(roundedRect: rect, xRadius: 92 * s, yRadius: 92 * s), angle: -90)
            NSColor.white.set()
            let sun = NSRect(x: rect.midX - 56 * s, y: rect.midY - 56 * s, width: 112 * s, height: 112 * s)
            NSBezierPath(ovalIn: sun).fill()
            if i == 2 {  // night: cut a crescent out of the moon
                sky.1.blended(withFraction: 0.5, of: sky.0)!.set()
                NSBezierPath(ovalIn: sun.offsetBy(dx: 40 * s, dy: 30 * s)).fill()
            }
        }
        return true
    }
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = Double(points * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(px).draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.current = nil
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
    }
}
