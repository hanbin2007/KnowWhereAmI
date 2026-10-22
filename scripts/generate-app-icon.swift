import AppKit

let size = 1024
guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let canvas = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                             bytesPerRow: size * 4, space: space,
                             bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("Cannot create icon context") }
let context = NSGraphicsContext(cgContext: canvas, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor(red: 0.055, green: 0.42, blue: 0.333, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSColor(white: 0.98, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 180, y: 150, width: 664, height: 724), xRadius: 48, yRadius: 48).fill()
for (y, end) in [(718.0, 740.0), (584.0, 670.0), (450.0, 740.0), (316.0, 550.0)] {
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 280, y: y))
    line.line(to: NSPoint(x: end, y: y))
    line.lineWidth = 34
    line.lineCapStyle = .round
    NSColor(red: 0.055, green: 0.42, blue: 0.333, alpha: 1).setStroke()
    line.stroke()
}
NSColor(red: 0.90, green: 0.45, blue: 0.34, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 550, y: 415, width: 208, height: 70), xRadius: 8, yRadius: 8).fill()
NSGraphicsContext.restoreGraphicsState()
guard let raster = canvas.makeImage(),
      let png = NSBitmapImageRep(cgImage: raster).representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
try png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
