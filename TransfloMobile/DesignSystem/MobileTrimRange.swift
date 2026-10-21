import SwiftUI

/// One selected interval, with large independent handles and equivalent VoiceOver adjustments.
struct MobileTrimRange: View {
    @Binding var start: Double
    @Binding var end: Double
    let duration: Double
    @Environment(Localizer.self) private var localizer

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                readout(.editorStartTime, value: start)
                Spacer()
                readout(.editorEndTime, value: end)
            }
            GeometryReader { proxy in
                let width = max(1, proxy.size.width - 44)
                let lower = position(start, width: width)
                let upper = position(end, width: width)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12).fill(AppColors.divider)
                        .frame(height: 42).padding(.horizontal, 22)
                    RoundedRectangle(cornerRadius: 8).fill(AppColors.accent.opacity(0.2))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.accent, lineWidth: 2))
                        .frame(width: max(4, upper - lower), height: 42).offset(x: lower + 22)
                    handle(isStart: true, width: width).offset(x: lower)
                    handle(isStart: false, width: width).offset(x: upper)
                }
                .frame(height: 60)
            }
            .frame(height: 60)
            .coordinateSpace(name: "trim.timeline")
        }
        .accessibilityElement(children: .contain)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func readout(_ title: L10nKey, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localizer.string(title)).font(.caption).foregroundStyle(AppColors.textSecondary)
            Text(TimeLabel.wholeSeconds(value)).font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }

    private func position(_ value: Double, width: Double) -> Double {
        min(1, max(0, value / max(0.01, duration))) * width
    }

    private func handle(isStart: Bool, width: Double) -> some View {
        RoundedRectangle(cornerRadius: 6).fill(AppColors.accent)
            .frame(width: 16, height: 48)
            .overlay { Capsule().fill(AppColors.accentContrast).frame(width: 3, height: 20) }
            .frame(width: 44, height: 60)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("trim.timeline"))
                .onChanged { gesture in
                    set((gesture.location.x - 22) / width * duration, isStart: isStart)
                }
                .onEnded { _ in AppFeedback.selection() })
            .accessibilityElement()
            .accessibilityLabel(localizer.string(isStart ? .editorStartTime : .editorEndTime))
            .accessibilityValue(TimeLabel.wholeSeconds(isStart ? start : end))
            .accessibilityAdjustableAction { direction in
                let delta = direction == .increment ? 1.0 : -1.0
                set((isStart ? start : end) + delta, isStart: isStart)
                AppFeedback.selection()
            }
            .accessibilityIdentifier(isStart ? "mobile.trim.start" : "mobile.trim.end")
    }

    private func set(_ value: Double, isStart: Bool) {
        let gap = min(0.1, duration)
        if isStart {
            start = min(max(0, value), max(0, end - gap))
        } else {
            end = min(duration, max(value, start + gap))
        }
    }
}
