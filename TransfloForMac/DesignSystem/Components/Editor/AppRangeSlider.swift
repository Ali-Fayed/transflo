import SwiftUI

/// A track with two handles selecting `lower...upper` inside `bounds` (left to right in every
/// language, like a timeline).
///
/// One drag gesture covers the whole track and reads positions in the track's own coordinates, so a
/// handle follows the pointer exactly while it moves. A drag (or a click on the track) takes the
/// handle nearest to where it starts, which keeps both handles reachable when they sit close together.
struct AppRangeSlider: View {
    @Environment(Localizer.self) private var localizer
    @Binding var lower: Double
    @Binding var upper: Double
    let bounds: ClosedRange<Double>
    /// Smallest allowed distance between the handles.
    let minimumSpan: Double
    @State private var dragging: Handle?

    private enum Handle { case lower, upper }
    private static let space = "transflo.rangeSlider"

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width - AppDimensions.Editor.handleSize)
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.divider).frame(height: AppDimensions.Editor.trackHeight)
                    .padding(.horizontal, AppDimensions.Editor.handleSize / 2)
                Capsule().fill(AppColors.accent)
                    .frame(width: max(0, position(upper, width) - position(lower, width)),
                           height: AppDimensions.Editor.trackHeight)
                    .offset(x: position(lower, width) + AppDimensions.Editor.handleSize / 2)
                handle(.lower, at: position(lower, width))
                handle(.upper, at: position(upper, width))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .coordinateSpace(.named(Self.space))
            .gesture(drag(width: width))
        }
        .frame(height: AppDimensions.Editor.handleSize * 2)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var span: Double { max(bounds.upperBound - bounds.lowerBound, .ulpOfOne) }

    private func position(_ value: Double, _ width: CGFloat) -> CGFloat {
        CGFloat((clamped(value) - bounds.lowerBound) / span) * width
    }

    private func clamped(_ value: Double) -> Double {
        let finite = value.isFinite ? value : bounds.lowerBound
        return min(max(finite, bounds.lowerBound), bounds.upperBound)
    }

    /// The value under a point on the track, where `x` is the handle's center.
    private func value(at x: CGFloat, width: CGFloat) -> Double {
        let fraction = Double(min(max(x - AppDimensions.Editor.handleSize / 2, 0), width) / width)
        return bounds.lowerBound + fraction * span
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { drag in
                let target = value(at: drag.location.x, width: width)
                let active = dragging ?? nearest(to: value(at: drag.startLocation.x, width: width))
                dragging = active
                move(active, to: target)
            }
            .onEnded { _ in dragging = nil }
    }

    /// The handle closer to `value`; past either end, that end's handle.
    private func nearest(to value: Double) -> Handle {
        if value <= clamped(lower) { return .lower }
        if value >= clamped(upper) { return .upper }
        return abs(value - clamped(lower)) <= abs(clamped(upper) - value) ? .lower : .upper
    }

    private func move(_ handle: Handle, to value: Double) {
        switch handle {
        case .lower: lower = max(bounds.lowerBound, min(value, clamped(upper) - minimumSpan))
        case .upper: upper = min(bounds.upperBound, max(value, clamped(lower) + minimumSpan))
        }
    }

    private func handle(_ handle: Handle, at x: CGFloat) -> some View {
        let step = max(span / 100, minimumSpan)
        return Circle()
            .fill(AppColors.surface)
            .overlay(Circle().strokeBorder(AppColors.accent, lineWidth: AppDimensions.Stroke.selection))
            .frame(width: AppDimensions.Editor.handleSize, height: AppDimensions.Editor.handleSize)
            .scaleEffect(dragging == handle ? 1.25 : 1)
            .animation(AppAnimations.standard, value: dragging)
            .offset(x: x)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(localizer.string(handle == .lower ? .editorStartTime : .editorEndTime))
            .accessibilityValue(Duration.seconds(clamped(handle == .lower ? lower : upper))
                .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 1))))
            .accessibilityAdjustableAction { direction in
                let current = handle == .lower ? clamped(lower) : clamped(upper)
                move(handle, to: direction == .increment ? current + step : current - step)
            }
    }
}
