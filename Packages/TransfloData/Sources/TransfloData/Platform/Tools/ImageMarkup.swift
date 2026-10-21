import CoreText
import Foundation
import TransfloDomain

/// Draws annotations, redaction boxes, backgrounds and collages with Core Graphics.
enum ImageMarkup {
    /// `#RRGGBB` → color (black when malformed).
    static func color(_ hex: String) -> CGColor {
        let value = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return CGColor(srgbRed: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                       blue: Double(value & 0xFF) / 255, alpha: 1)
    }

    static func annotate(_ image: CGImage, with annotations: [Annotation]) -> CGImage? {
        ImageScaling.draw(image, width: image.width, height: image.height) { context in
            let size = CGSize(width: image.width, height: image.height)
            context.draw(image, in: CGRect(origin: .zero, size: size))
            annotations.forEach { draw($0, in: context, size: size) }
        }
    }

    static func redact(_ image: CGImage, boxes: [NormalizedRect]) -> CGImage? {
        ImageScaling.draw(image, width: image.width, height: image.height) { context in
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            for box in boxes {
                let pixels = box.pixels(width: image.width, height: image.height)
                context.fill(rect(box, height: image.height, pixels: pixels))
            }
        }
    }

    static func background(_ image: CGImage, color hex: String) -> CGImage? {
        ImageScaling.draw(image, width: image.width, height: image.height) { context in
            let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            context.setFillColor(color(hex))
            context.fill(bounds)
            context.draw(image, in: bounds)
        }
    }

    /// A grid of images, each fitted into a cell the size of the first (capped at 1200 px).
    static func collage(_ images: [CGImage], columns: Int, spacing: Int, background hex: String) -> CGImage? {
        guard let first = images.first else { return nil }
        return try? collage(first: first, layout: (columns, spacing),
                            background: hex,
                            count: images.count) { images[$0] }
    }

    /// Draws and releases each input before decoding the next, with a bounded output canvas.
    static func collage(
        first: CGImage,
        layout: (columns: Int, spacing: Int),
        background hex: String,
        count: Int,
        imageAt: (Int) throws(JobError) -> CGImage
    ) throws(JobError) -> CGImage {
        let spacing = layout.spacing
        guard count > 0, layout.columns > 0 else { throw .unsupported }
        let columns = min(layout.columns, count)
        let scale = min(1, 1200 / Double(max(first.width, first.height)))
        let cell = CGSize(width: Double(first.width) * scale, height: Double(first.height) * scale)
        let rows = (count - 1) / columns + 1
        let gap = CGFloat(max(spacing, 0))
        let size = CGSize(width: (CGFloat(columns) * (cell.width + gap) + gap).rounded(.up),
                          height: (CGFloat(rows) * (cell.height + gap) + gap).rounded(.up))
        guard RasterLimits.allows(size), let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw .failed }
        context.interpolationQuality = .high
        context.setFillColor(color(hex))
        context.fill(CGRect(origin: .zero, size: size))
        for index in 0..<count {
            try RasterLimits.withPool { () throws(JobError) in
                let image = try imageAt(index)
                let column = CGFloat(index % columns)
                let row = CGFloat(index / columns)
                let slot = CGRect(x: gap + column * (cell.width + gap),
                                  y: size.height - (gap + row * (cell.height + gap)) - cell.height,
                                  width: cell.width, height: cell.height)
                context.draw(image, in: fit(image, in: slot))
            }
        }
        guard let result = context.makeImage() else { throw .failed }
        return result
    }

    private static func fit(_ image: CGImage, in slot: CGRect) -> CGRect {
        let scale = min(slot.width / CGFloat(image.width), slot.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let origin = CGPoint(x: slot.midX - size.width / 2, y: slot.midY - size.height / 2)
        return CGRect(origin: origin, size: size)
    }

    /// Flips a top-left pixel rect into Core Graphics' bottom-left space.
    private static func rect(_ box: NormalizedRect, height: Int, pixels: PixelRect) -> CGRect {
        CGRect(x: pixels.x, y: height - pixels.y - pixels.height, width: pixels.width, height: pixels.height)
    }

    private static func point(_ point: UnitPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
    }

    static func draw(_ annotation: Annotation, in context: CGContext, size: CGSize) {
        let weight = max(1, annotation.weight * min(size.width, size.height))
        let points = annotation.points.map { point($0, size) }
        context.setStrokeColor(color(annotation.color))
        context.setFillColor(color(annotation.color))
        context.setLineWidth(weight)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch annotation.kind {
        case .rectangle where points.count >= 2:
            context.stroke(CGRect(x: min(points[0].x, points[1].x), y: min(points[0].y, points[1].y),
                                  width: abs(points[1].x - points[0].x), height: abs(points[1].y - points[0].y)))
        case .arrow where points.count >= 2:
            drawArrow(from: points[0], to: points[1], weight: weight, in: context)
        case .freehand where points.count >= 2:
            context.addLines(between: points)
            context.strokePath()
        case .text(let text) where !points.isEmpty:
            let font = PlatformFont.boldSystemFont(ofSize: weight * 4)
            // CoreText takes the color from the context, which reads the same on AppKit and UIKit.
            context.setFillColor(color(annotation.color))
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
                .font: font, NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
            ]))
            context.textPosition = CGPoint(x: points[0].x, y: points[0].y - font.ascender)
            CTLineDraw(line, context)
        default:
            break
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, weight: CGFloat, in context: CGContext) {
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = weight * 4
        context.move(to: end)
        context.addLine(to: CGPoint(x: end.x - head * cos(angle - .pi / 6), y: end.y - head * sin(angle - .pi / 6)))
        context.addLine(to: CGPoint(x: end.x - head * cos(angle + .pi / 6), y: end.y - head * sin(angle + .pi / 6)))
        context.closePath()
        context.fillPath()
    }
}
