import SwiftUI

/// The home screen's landing zone: an icon, a title and a hint over a dashed outline that lights
/// up in the accent while files hover over it. `actions` sit underneath (pickers).
struct AppDropArea<Actions: View>: View {
    let symbol: AppSymbol
    let title: L10nKey
    let hint: L10nKey
    let isTargeted: Bool
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppDimensions.Mobile.dropAreaRadius, style: .continuous)
        VStack(spacing: AppDimensions.Spacing.large) {
            AppIcon(symbol: symbol, size: AppDimensions.Mobile.dropIconSize)
                .foregroundStyle(isTargeted ? AppColors.accent : AppColors.textSecondary)
            AppText(title, style: .title)
            AppText(hint, style: .caption, color: .secondary)
                .multilineTextAlignment(.center)
            actions()
        }
        .padding(AppDimensions.Spacing.xLarge)
        .frame(maxWidth: .infinity, minHeight: AppDimensions.Mobile.dropAreaMinHeight)
        .background(shape.fill(isTargeted ? AppColors.accent.opacity(0.08) : AppColors.surface))
        .overlay(shape.strokeBorder(isTargeted ? AppColors.accent : AppColors.divider,
                                    style: StrokeStyle(lineWidth: AppDimensions.Stroke.selection, dash: [8, 6])))
        .animation(AppAnimations.standard, value: isTargeted)
        .accessibilityElement(children: .contain)
    }
}
