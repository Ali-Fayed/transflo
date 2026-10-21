import SwiftUI

/// A localized selection count, shared by all wheel kinds.
struct AppCountBadge: View {
    @Environment(Localizer.self) private var localizer
    let count: Int

    var body: some View {
        AppText(verbatim: count.formatted(.number.locale(localizer.locale)), style: .wedgeCompact, color: .onAccent)
            .padding(.horizontal, AppDimensions.Spacing.xSmall)
            .frame(minWidth: AppDimensions.Wheel.countBadgeDiameter)
            .frame(height: AppDimensions.Wheel.countBadgeDiameter)
            .background(AppColors.accent, in: Capsule())
            .overlay(Capsule().stroke(AppColors.petalEdge, lineWidth: AppDimensions.Stroke.hairline))
            .accessibilityLabel(localizer.string(.wheelItemCount,
                                                arguments: [count.formatted(.number.locale(localizer.locale))]))
            .accessibilityIdentifier("transflo.wheel.item-count")
    }
}
