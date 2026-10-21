import SwiftUI

/// The Mac welcome scene: an accent-colored wheel reveal alongside live personalization.
struct AppOnboardingHero: View {
    let customization: CustomizationViewModel

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.xLarge) {
            VStack(spacing: AppDimensions.Spacing.large) {
                AppFlowMark(size: AppDimensions.Flow.heroMark)
                AppText(.flowLocal, style: .caption, color: .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: AppDimensions.Onboarding.illustrationWidth * 0.6)
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
                AppText(.onboardingWelcome, style: .welcomeTitle).appEntrance(step: 0)
                AppText(.welcomeTitle, style: .headline).appEntrance(step: 1)
                AppText(.welcomeDescription, style: .caption, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true).appEntrance(step: 2)
                AppAccentPicker(selection: Binding(get: { customization.preferences.accentHex },
                                                   set: { hex in customization.update { $0.accentHex = hex } }))
                    .appEntrance(step: 3)
                AppText(.onboardingWelcomeHint, style: .caption, color: .secondary).appEntrance(step: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppDimensions.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [AppColors.onboardingStart, AppColors.onboardingEnd],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
        // A chosen accent is a translucent tint, so the canvas needs an opaque base beneath it.
        .background(AppColors.background, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
    }
}
