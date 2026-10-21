import SwiftUI

/// A labeled slider drawn for the editors: the accent fill grows from the control's resting value,
/// the thumb lifts while dragged, and the value sits in a chip beside the label. A drag near the
/// resting value snaps to it with a tick of feedback; double-tapping the label returns to it.
///
/// The track follows the reading direction, filling from the right in Arabic. Assistive technologies
/// get a native slider in its place.
struct AppSlider: View {
    @Environment(Localizer.self) private var localizer
    @Environment(\.layoutDirection) private var direction
    let label: L10nKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// The current value, already formatted by the caller.
    let valueText: String
    /// Where the fill starts, the drag snaps and double-tap returns; the lower bound when nil.
    var defaultValue: Double?
    @State private var isDragging = false

    private typealias Metrics = AppDimensions.Editor

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            HStack {
                AppText(label, style: .body)
                Spacer()
                chip
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { if let defaultValue { value = defaultValue } }
            track
        }
        .sensoryFeedback(.selection, trigger: isAtDefault) { _, atDefault in atDefault && isDragging }
        // VoiceOver and UI tests see a real slider with this label and value, not a custom drawing.
        .accessibilityRepresentation {
            Slider(value: Binding(get: { clamped(value) }, set: { value = clamped($0) }), in: range) {
                Text(localizer.string(label))
            }
            .accessibilityValue(valueText)
        }
    }

    private var chip: some View {
        AppText(verbatim: valueText, style: .caption, color: isDragging ? .onAccent : .secondary)
            .monospacedDigit()
            .padding(.horizontal, AppDimensions.Spacing.small)
            .padding(.vertical, AppDimensions.Spacing.xSmall / 2)
            .background(isDragging ? AppColors.accent : AppColors.divider.opacity(0.5), in: Capsule())
            .animation(AppAnimations.standard, value: isDragging)
    }

    private var track: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width - Metrics.sliderThumb)
            let thumb = position(value, width)
            let origin = position(anchor, width)
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.divider).frame(height: Metrics.trackHeight)
                    .padding(.horizontal, Metrics.sliderThumb / 2)
                Capsule().fill(AppColors.accent)
                    .frame(width: abs(thumb - origin), height: Metrics.trackHeight)
                    .offset(x: min(thumb, origin) + Metrics.sliderThumb / 2)
                if defaultValue != nil {
                    Capsule().fill(AppColors.textSecondary)
                        .frame(width: AppDimensions.Stroke.selection, height: Metrics.sliderTick)
                        .offset(x: origin + (Metrics.sliderThumb - AppDimensions.Stroke.selection) / 2)
                }
                Circle().fill(AppColors.surface)
                    .overlay(Circle().strokeBorder(AppColors.accent, lineWidth: AppDimensions.Stroke.selection))
                    .frame(width: Metrics.sliderThumb, height: Metrics.sliderThumb)
                    .scaleEffect(isDragging ? 1.15 : 1)
                    .animation(AppAnimations.standard, value: isDragging)
                    .offset(x: thumb)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(drag(width: width))
        }
        .frame(height: Metrics.sliderThumb * 1.5)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var span: Double { max(range.upperBound - range.lowerBound, .ulpOfOne) }
    private var anchor: Double { clamped(defaultValue ?? range.lowerBound) }
    private var isAtDefault: Bool { defaultValue.map { abs(clamped(value) - $0) < .ulpOfOne } ?? false }

    private func clamped(_ value: Double) -> Double {
        let finite = value.isFinite ? value : range.lowerBound
        return min(max(finite, range.lowerBound), range.upperBound)
    }

    /// The thumb's leading edge for `value`, mirrored in right-to-left languages.
    private func position(_ value: Double, _ width: CGFloat) -> CGFloat {
        let fraction = (clamped(value) - range.lowerBound) / span
        return CGFloat(direction == .rightToLeft ? 1 - fraction : fraction) * width
    }

    private func value(at x: CGFloat, width: CGFloat) -> Double {
        let fraction = Double(min(max(x - Metrics.sliderThumb / 2, 0), width) / width)
        let target = range.lowerBound + (direction == .rightToLeft ? 1 - fraction : fraction) * span
        if let defaultValue, abs(target - defaultValue) < span * Metrics.sliderSnap { return defaultValue }
        return target
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                isDragging = true
                value = value(at: drag.location.x, width: width)
            }
            .onEnded { _ in isDragging = false }
    }
}
