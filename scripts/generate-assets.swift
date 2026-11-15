import AppKit

// Code-drawn brand mark; no external image or font dependencies.
func render(_ file: String, size: Int, scale: CGFloat = 1) throws {
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let width = CGFloat(size)
  NSColor(red: 16/255, green: 21/255, blue: 19/255, alpha: 1).setFill()
  NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: width)).fill()
  let side = width * 0.66 * scale
  let origin = (width - side) / 2
  NSColor(red: 180/255, green: 228/255, blue: 187/255, alpha: 1).setFill()
  NSBezierPath(roundedRect: NSRect(x: origin, y: origin, width: side, height: side), xRadius: side * 0.32, yRadius: side * 0.32).fill()
  NSColor(red: 16/255, green: 21/255, blue: 19/255, alpha: 1).setFill()
  for fraction: CGFloat in [0.34, 0.55] {
    NSBezierPath(roundedRect: NSRect(x: origin + side * fraction, y: origin + side * 0.29, width: side * 0.11, height: side * 0.42), xRadius: side * 0.035, yRadius: side * 0.035).fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: file))
}
try render("assets/icon.png", size: 1024)
try render("assets/adaptive-icon.png", size: 1024)
try render("assets/splash-icon.png", size: 1024, scale: 0.42)
try render("assets/favicon.png", size: 64)
try render("docs/icon.png", size: 256)
