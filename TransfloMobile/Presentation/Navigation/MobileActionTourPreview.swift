import SwiftUI

/// Mobile onboarding demonstrates the real list interaction while keeping the wheel as the brand mark.
struct MobileActionTourPreview: View {
    let stage: Int
    @Environment(Localizer.self) private var localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppFlowMark(size: 56, animated: false).frame(maxWidth: .infinity)
            if stage == 2 {
                row(.mobileSavePhotos, symbol: "photo.on.rectangle")
                row(.mobileSaveFiles, symbol: "folder")
            } else {
                row(.wheelConvert, symbol: "arrow.triangle.2.circlepath")
                row(.wheelTools, symbol: "slider.horizontal.3")
                row(.settingsRecipes, symbol: AppSymbol.recipe.rawValue)
            }
        }
        .padding(20)
        .accessibilityIdentifier("mobile.onboarding.actions")
    }

    private func row(_ label: L10nKey, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(AppColors.accent).frame(width: 24)
            Text(localizer.string(label)).font(.headline)
            Spacer()
            Image(systemName: "chevron.forward").font(.caption).foregroundStyle(AppColors.textSecondary)
        }
        .padding(16).background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
