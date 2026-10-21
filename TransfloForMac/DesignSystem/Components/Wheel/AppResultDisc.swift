import SwiftUI

/// What is left of the wheel after a drop: the hub, ringed by the job's progress, ending in a check
/// that draws itself in (with a small pulse) or a cross that shakes, plus a short reason on failure.
///
/// The disc enters slightly larger and settles, so the wheel appears to fold into its hub.
/// With Reduce Motion, states change without movement.
struct AppResultDisc: View {
    let status: AppProgressRing.Status
    /// Short explanation shown under the disc, for failures.
    var caption: L10nKey?

    @State private var appeared = false
    @State private var glyphProgress: CGFloat = 0
    @State private var spinning = false
    @State private var celebration = 0

    private static let diameter = AppDimensions.ResultDisc.diameter

    var body: some View {
        VStack(spacing: AppDimensions.Spacing.small) {
            disc
                .scaleEffect(appeared ? 1 : AppDimensions.ResultDisc.enterScale)
                .opacity(appeared ? 1 : 0)
                .keyframeAnimator(initialValue: ResultMotion(), trigger: celebration) { content, motion in
                    content.scaleEffect(motion.scale).offset(x: motion.offset)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) { scaleKeyframes }
                    KeyframeTrack(\.offset) { shakeKeyframes }
                }
            if let caption {
                AppText(caption, style: .caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, AppDimensions.Spacing.medium)
                    .padding(.vertical, AppDimensions.Spacing.small)
                    .appGlass(.floating, in: Capsule())
                    .frame(maxWidth: AppDimensions.ResultDisc.captionWidth)
                    .transition(.opacity)
            }
        }
        .onAppear(perform: enter)
        .onChange(of: status, initial: true) { _, status in finish(status) }
    }

    private var disc: some View {
        ZStack {
            Circle().fill(AppColors.hubWell)
            ring
                .padding(AppDimensions.ResultDisc.ringInset)
            glyph
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .background(Circle().fill(.clear).appGlass(.floating, in: Circle()))
    }

    @ViewBuilder private var ring: some View {
        let stroke = StrokeStyle(lineWidth: AppDimensions.ResultDisc.ringStroke, lineCap: .round)
        ZStack {
            Circle().stroke(AppColors.divider, lineWidth: AppDimensions.ResultDisc.ringStroke)
            switch status {
            case .progress(let fraction) where fraction < 0.02:
                Circle().trim(from: 0, to: 0.22).stroke(AppColors.accent, style: stroke)
                    .rotationEffect(.degrees(spinning ? 270 : -90))
                    .onAppear { withAnimation(AppAnimations.resultSpin) { spinning = true } }
            case .progress(let fraction):
                Circle().trim(from: 0, to: min(fraction, 1)).stroke(AppColors.accent, style: stroke)
                    .rotationEffect(.degrees(-90))
                    .animation(AppAnimations.progress, value: fraction)
            case .success:
                Circle().stroke(AppColors.accent, style: stroke)
            case .failure:
                Circle().stroke(AppColors.danger, style: stroke)
            }
        }
    }

    @ViewBuilder private var glyph: some View {
        let stroke = StrokeStyle(lineWidth: AppDimensions.ResultDisc.glyphStroke, lineCap: .round, lineJoin: .round)
        let size = AppDimensions.ResultDisc.glyphSize
        switch status {
        case .progress:
            EmptyView()
        case .success:
            ResultCheckmark().trim(from: 0, to: glyphProgress).stroke(AppColors.accent, style: stroke)
                .frame(width: size, height: size)
        case .failure:
            ResultCross().trim(from: 0, to: glyphProgress).stroke(AppColors.danger, style: stroke)
                .frame(width: size, height: size)
        }
    }

    @KeyframeTrackContentBuilder<CGFloat> private var scaleKeyframes: some KeyframeTrackContent<CGFloat> {
        if status == .success {
            SpringKeyframe(AppDimensions.ResultDisc.pulseScale, duration: 0.16)
            SpringKeyframe(1, duration: 0.3)
        } else {
            LinearKeyframe(1, duration: 0.01)
        }
    }

    @KeyframeTrackContentBuilder<CGFloat> private var shakeKeyframes: some KeyframeTrackContent<CGFloat> {
        let distance = AppDimensions.ResultDisc.shakeDistance
        if status == .failure {
            CubicKeyframe(distance, duration: 0.07)
            CubicKeyframe(-distance, duration: 0.07)
            CubicKeyframe(distance * 0.6, duration: 0.07)
            CubicKeyframe(-distance * 0.6, duration: 0.07)
            CubicKeyframe(0, duration: 0.07)
        } else {
            LinearKeyframe(0, duration: 0.01)
        }
    }

    private func enter() {
        guard let animation = AppAnimations.resultEnter else {
            appeared = true
            return
        }
        withAnimation(animation) { appeared = true }
    }

    /// A finished job draws its glyph in, then pulses (success) or shakes (failure).
    private func finish(_ status: AppProgressRing.Status) {
        guard status == .success || status == .failure else { return }
        withAnimation(AppAnimations.resultGlyph) { glyphProgress = 1 }
        if AppAnimations.resultPulse { celebration += 1 }
    }
}

/// Animated scale and horizontal offset for the result pulse and shake.
private struct ResultMotion {
    var scale: CGFloat = 1
    var offset: CGFloat = 0
}

/// A tick drawn left to right, so trimming it reads as handwriting.
nonisolated private struct ResultCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY + rect.height * 0.04))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - rect.height * 0.2))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.22))
        }
    }
}

/// Two strokes of a cross, drawn one after the other.
nonisolated private struct ResultCross: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
        return Path { path in
            path.move(to: CGPoint(x: inset.minX, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
            path.move(to: CGPoint(x: inset.maxX, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
        }
    }
}
