import SwiftUI

/// A titled group of settings rows on a glass card.
struct SettingsSection<Content: View>: View {
    let title: L10nKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            AppText(title, style: .headline, color: .secondary)
                .padding(.horizontal, AppDimensions.Spacing.xSmall)
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
                content()
            }
            .padding(AppDimensions.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(.card, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
        }
    }
}
