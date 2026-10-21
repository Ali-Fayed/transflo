import SwiftUI

/// The small glass card the HUD uses for jobs and hints: an accessory, then text. Tappable.
struct AppHUDCard<Accessory: View, Content: View>: View {
    let onTap: () -> Void
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let text: () -> Content

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.medium) {
            accessory()
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                text()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppDimensions.Spacing.large)
        .frame(width: AppDimensions.HUD.width, height: AppDimensions.HUD.height)
        .appGlass(.floating, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
        .padding(AppDimensions.Wheel.margin)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
