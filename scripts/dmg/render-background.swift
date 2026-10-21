import AppKit

// The installer window's artwork, on Transflo's dark brand background (the app icon's charcoal).
// Finder keeps a disk image's background fixed (it doesn't follow light or dark mode), so the design
// is one look everywhere.
// Rendered at 2× for crisp text on Retina displays; Finder sees a 640 × 350 point image.
let width: CGFloat = 640
let height: CGFloat = 350
let output = URL(fileURLWithPath: CommandLine.arguments[1])
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 700,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let context = graphics.cgContext
context.scaleBy(x: 2, y: 2)
func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
// Transflo's brand palette.
let inkTop = rgb(0x24282B), inkBottom = rgb(0x121416)
let teal = rgb(0x3FB8A5), title = rgb(0xEDEBE6), gray = rgb(0x9FA6A8)
NSGradient(starting: inkBottom, ending: inkTop)?.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: 90)

func text(_ string: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (string as NSString).draw(in: CGRect(x: 30, y: height - top - 45, width: width - 60, height: 45),
                             withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                              .foregroundColor: color, .paragraphStyle: paragraph])
}
text("Install Transflo", top: 24, size: 32, weight: .bold, color: title)
text("Drag Transflo to Applications to get started.", top: 70, size: 15, weight: .medium, color: gray)

// Finder draws icon labels in dark text over a picture background, so each label (centered under
// the icons Finder places at x 170 and 470) sits on a light pill.
for centerX in [170.0, 470.0] {
    let pill = CGRect(x: centerX - 62, y: height - 254, width: 124, height: 26)
    title.withAlphaComponent(0.92).setFill()
    NSBezierPath(roundedRect: pill, xRadius: 13, yRadius: 13).fill()
}

// Finder places the two real, draggable icons on either side of this arrow.
teal.setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 2.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
let arrowY = height - 175
arrow.move(to: CGPoint(x: 282, y: arrowY))
arrow.line(to: CGPoint(x: 358, y: arrowY))
arrow.move(to: CGPoint(x: 346, y: arrowY + 10))
arrow.line(to: CGPoint(x: 358, y: arrowY))
arrow.line(to: CGPoint(x: 346, y: arrowY - 10))
arrow.stroke()
text("Then open Transflo from Applications.", top: 278, size: 13, weight: .medium, color: gray)
NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: output)
