import SwiftUI

/// A welcoming, accent-aware empty history with a concrete next step.
struct AppHistoryEmptyState: View {
    var message: L10nKey = .flowHistoryDetail

    var body: some View {
        VStack(spacing: AppDimensions.Spacing.large) {
            AppFlowMark(size: AppDimensions.Onboarding.heroIconSize)
            AppText(.flowHistoryTitle, style: .headline)
            AppText(message, style: .caption, color: .secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppDimensions.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
