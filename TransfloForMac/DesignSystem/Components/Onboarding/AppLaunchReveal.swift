import SwiftUI

/// A brief, noninteractive brand reveal over the already-loaded app, following its saved accent.
struct AppLaunchReveal: View {
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: AppDimensions.Spacing.xLarge) {
                AppFlowMark(size: AppDimensions.Flow.splashMark)
                    .rotationEffect(.degrees(expanded ? 30 : -30))
                    .scaleEffect(expanded ? 1 : 0.72)
                    .opacity(expanded ? 1 : 0)
                Capsule().fill(AppColors.accent.opacity(0.12))
                    .frame(width: 100, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(AppColors.accent).frame(width: expanded ? 100 : 0, height: 3)
                    }
                AppText(.appName, style: .welcomeTitle)
                AppText(.flowLocal, style: .caption, color: .secondary)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { expanded = true }
            if !reduceMotion, AppAnimations.brandReveal != nil {
                do { try await Task.sleep(for: .milliseconds(1100)) } catch { return }
            }
            withAnimation(AppAnimations.standard) { onFinished() }
        }
    }
}
