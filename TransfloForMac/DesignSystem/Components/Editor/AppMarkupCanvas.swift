import SwiftUI
import TransfloDomain

/// A transparent drawing surface: shows marks and redaction boxes and reports drags in unit
/// coordinates (origin top-left, the same in every language, like the image itself).
struct AppMarkupCanvas: View {
    let annotations: [Annotation]
    let redactions: [NormalizedRect]
    let onBegin: (TransfloDomain.UnitPoint) -> Void
    let onMove: (TransfloDomain.UnitPoint) -> Void
    let onEnd: () -> Void
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                MarkupDrawing.draw(annotations: annotations, redactions: redactions, in: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = Self.unit(value.location, in: proxy.size)
                    if isDragging {
                        onMove(point)
                    } else {
                        isDragging = true
                        onBegin(point)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    onEnd()
                })
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private static func unit(_ location: CGPoint, in size: CGSize) -> TransfloDomain.UnitPoint {
        TransfloDomain.UnitPoint(x: location.x / max(size.width, 1), y: location.y / max(size.height, 1))
    }
}
