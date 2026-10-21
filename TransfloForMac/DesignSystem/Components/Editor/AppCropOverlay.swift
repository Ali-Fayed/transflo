import SwiftUI
import TransfloDomain

/// A crop box over a preview: drag inside to move it, drag a corner to resize. Reports
/// proposals in normalized coordinates; the owner applies constraints (aspect ratio).
struct AppCropOverlay: View {
    enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
    }

    let rect: NormalizedRect
    let onChange: (NormalizedRect, Corner?) -> Void
    var showsGrid = false
    @State private var dragStart: NormalizedRect?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let frame = CGRect(x: rect.x * size.width, y: rect.y * size.height,
                               width: rect.width * size.width, height: rect.height * size.height)
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRect(frame)
                }
                .fill(AppColors.cropShade, style: FillStyle(eoFill: true))
                Rectangle()
                    .strokeBorder(AppColors.accent, lineWidth: AppDimensions.Stroke.selection)
                    .contentShape(Rectangle())
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .gesture(drag(size: size, corner: nil))
                if showsGrid {
                    Path { path in
                        for third in [1.0 / 3, 2.0 / 3] {
                            path.move(to: CGPoint(x: frame.minX + frame.width * third, y: frame.minY))
                            path.addLine(to: CGPoint(x: frame.minX + frame.width * third, y: frame.maxY))
                            path.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * third))
                            path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * third))
                        }
                    }.stroke(.white.opacity(0.5), lineWidth: 0.5).allowsHitTesting(false)
                }
                ForEach(Corner.allCases, id: \.self) { corner in
                    Rectangle()
                        .fill(AppColors.accent)
                        .frame(width: AppDimensions.Editor.handleSize, height: AppDimensions.Editor.handleSize)
                        .offset(cornerOffset(corner, frame: frame))
                        .gesture(drag(size: size, corner: corner))
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func cornerOffset(_ corner: Corner, frame: CGRect) -> CGSize {
        let half = AppDimensions.Editor.handleSize / 2
        let x = [Corner.topLeading, .bottomLeading].contains(corner) ? frame.minX : frame.maxX
        let y = [Corner.topLeading, .topTrailing].contains(corner) ? frame.minY : frame.maxY
        return CGSize(width: x - half, height: y - half)
    }

    private func drag(size: CGSize, corner: Corner?) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = dragStart ?? rect
                if dragStart == nil { dragStart = rect }
                let deltaX = Double(value.translation.width / max(size.width, 1))
                let deltaY = Double(value.translation.height / max(size.height, 1))
                onChange(CropGeometry.proposal(from: start, corner: corner, deltaX: deltaX, deltaY: deltaY), corner)
            }
            .onEnded { _ in dragStart = nil }
    }
}
