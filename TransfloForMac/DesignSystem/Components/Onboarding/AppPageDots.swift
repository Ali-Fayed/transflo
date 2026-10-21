import SwiftUI

/// A single VoiceOver element announces progress without exposing decorative dots as controls.
struct AppPageDots: View {
    let page: Int
    let count: Int
    @Environment(Localizer.self) private var localizer

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.small) {
            ForEach(0..<count, id: \.self) { index in
                Capsule().fill(index == page ? AppColors.accent : AppColors.divider)
                    .frame(width: index == page ? AppDimensions.Onboarding.selectedDotWidth
                           : AppDimensions.Onboarding.dotSize, height: AppDimensions.Onboarding.dotSize)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizer.string(.onboardingProgress, arguments: [number(page + 1), number(count)]))
        .accessibilityIdentifier("transflo.onboarding.progress")
    }

    private func number(_ value: Int) -> String {
        let locale = localizer.isRightToLeft ? Locale(identifier: "ar@numbers=arab") : localizer.locale
        return value.formatted(.number.locale(locale))
    }
}
