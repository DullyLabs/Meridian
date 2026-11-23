// Fits the iOS app's square icon (first argument) into the macOS icon tile and writes an .iconset at the second argument.
import AppKit

let art = NSImage(contentsOfFile: CommandLine.arguments[1])!

func draw(_ size: Double) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let s = size / 1024
        let rect = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        NSBezierPath(roundedRect: rect, xRadius: 185 * s, yRadius: 185 * s).addClip()
        art.draw(in: rect)
        return true
    }
}

let dir = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = Double(points * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current!.imageInterpolation = .high
        draw(px).draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.current = nil
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name))
    }
}
