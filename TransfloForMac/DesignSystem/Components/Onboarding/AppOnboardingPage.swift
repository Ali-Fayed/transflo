import SwiftUI

/// A stable two-column canvas that follows the interface's leading edge in either language.
struct AppOnboardingPage<Illustration: View, Content: View>: View {
    @ViewBuilder let illustration: () -> Illustration
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.xLarge) {
            illustration().frame(width: AppDimensions.Onboarding.illustrationWidth)
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.large, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: AppDimensions.Onboarding.contentHeight)
    }
}
