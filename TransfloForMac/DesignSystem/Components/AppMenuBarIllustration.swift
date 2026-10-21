import SwiftUI

/// A small drawing of the menu bar with Transflo's icon highlighted and a caption pointing at it.
/// Decorative: VoiceOver skips it (the Welcome text says the same).
struct AppMenuBarIllustration: View {
    let caption: L10nKey

    private typealias Metrics = AppDimensions.MenuBarIllustration

    var body: some View {
        VStack(spacing: AppDimensions.Spacing.medium) {
            HStack(spacing: AppDimensions.Spacing.medium) {
                AppText(.appName, style: .headline)
                Spacer()
                AppIcon(symbol: .menuBar, size: Metrics.transfloIconSize)
                    .foregroundStyle(AppColors.accentContrast)
                    .frame(width: Metrics.iconTile.width, height: Metrics.iconTile.height)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: Metrics.iconCornerRadius))
                AppIcon(symbol: .menuBarWifi, size: Metrics.statusIconSize)
                AppIcon(symbol: .menuBarBattery, size: Metrics.batteryIconSize)
            }
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, Metrics.horizontalPadding)
            .padding(.vertical, Metrics.verticalPadding)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadius).strokeBorder(AppColors.divider))
            HStack {
                Spacer()
                VStack(spacing: AppDimensions.Spacing.xSmall) {
                    AppIcon(symbol: .arrowUp, size: Metrics.arrowSize)
                        .foregroundStyle(AppColors.accent)
                    AppText(caption, style: .caption, color: .secondary)
                }
                .frame(width: Metrics.captionWidth)
            }
        }
        // Follows macOS's menu-bar arrangement in both interface languages.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }
}
