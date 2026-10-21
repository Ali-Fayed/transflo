import SwiftUI

/// A quiet placeholder for an empty list: a large symbol and one line of guidance.
struct AppEmptyState: View {
    let symbol: AppSymbol
    let message: L10nKey

    var body: some View {
        VStack(spacing: AppDimensions.Spacing.medium) {
            AppIcon(symbol: symbol, size: AppDimensions.Jobs.emptyIconSize)
                .foregroundStyle(AppColors.textSecondary)
            AppText(message, color: .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
