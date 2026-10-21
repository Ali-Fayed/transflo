import SwiftUI
import TransfloDomain

/// Draws marks and redaction boxes into a canvas the same way the engines burn them in.
enum MarkupDrawing {
    static func draw(
        annotations: [Annotation], redactions: [NormalizedRect], in context: inout GraphicsContext, size: CGSize
    ) {
        for box in redactions {
            let rect = CGRect(x: box.x * size.width, y: box.y * size.height,
                              width: box.width * size.width, height: box.height * size.height)
            context.fill(Path(rect), with: .color(AppMarkupPalette.color(AppMarkupPalette.redaction)))
        }
        annotations.forEach { draw($0, in: &context, size: size) }
    }

    private static func draw(_ annotation: Annotation, in context: inout GraphicsContext, size: CGSize) {
        let weight = max(1, annotation.weight * min(size.width, size.height))
        let color = AppMarkupPalette.color(annotation.color)
        let points = annotation.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let stroke = StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round)
        switch annotation.kind {
        case .rectangle where points.count >= 2:
            let rect = CGRect(x: min(points[0].x, points[1].x), y: min(points[0].y, points[1].y),
                              width: abs(points[1].x - points[0].x), height: abs(points[1].y - points[0].y))
            context.stroke(Path(rect), with: .color(color), style: stroke)
        case .arrow where points.count >= 2:
            context.stroke(Path { $0.addLines([points[0], points[1]]) }, with: .color(color), style: stroke)
            context.fill(arrowHead(from: points[0], to: points[1], weight: weight), with: .color(color))
        case .freehand where points.count >= 2:
            context.stroke(Path { $0.addLines(points) }, with: .color(color), style: stroke)
        case .text(let text) where !points.isEmpty:
            let label = Text(text).font(.system(size: weight * 4, weight: .bold)).foregroundStyle(color)
            context.draw(label, at: points[0], anchor: .topLeading)
        default:
            break
        }
    }

    private static func arrowHead(from start: CGPoint, to end: CGPoint, weight: CGFloat) -> Path {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = weight * 4
        return Path { path in
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - head * cos(angle - .pi / 6), y: end.y - head * sin(angle - .pi / 6)))
            path.addLine(to: CGPoint(x: end.x - head * cos(angle + .pi / 6), y: end.y - head * sin(angle + .pi / 6)))
            path.closeSubpath()
        }
    }
}
