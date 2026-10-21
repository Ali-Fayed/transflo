import SwiftUI

/// The collapsed shelf: a glass pill with the count; clicking it expands the shelf.
struct AppShelfPill: View {
    @Environment(Localizer.self) private var localizer
    let count: Int
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            VStack(spacing: AppDimensions.Spacing.xSmall) {
                AppIcon(symbol: .shelf, size: AppDimensions.IconSize.medium)
                    .foregroundStyle(AppColors.accent)
                AppText(verbatim: String(count), style: .caption)
            }
            .frame(width: AppDimensions.Shelf.collapsedSize, height: AppDimensions.Shelf.collapsedSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .appFocusRing(Circle())
        .appGlass(.floating, in: Circle())
        .help(localizer.string(.shelfExpand))
        .accessibilityLabel(localizer.string(.shelfExpand))
    }
}
