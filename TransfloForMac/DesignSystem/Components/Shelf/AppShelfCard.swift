import SwiftUI

/// The expanded shelf on glass: header (title, count, collapse, clear) over scrolling tiles.
struct AppShelfCard<Tiles: View>: View {
    let count: Int
    let onCollapse: () -> Void
    let onClear: () -> Void
    @ViewBuilder let tiles: () -> Tiles

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppDimensions.Spacing.small) {
                AppIcon(symbol: .shelf, size: AppDimensions.IconSize.medium)
                    .foregroundStyle(AppColors.accent)
                AppText(.shelfTitle, style: .headline)
                AppText(verbatim: String(count), style: .caption, color: .secondary)
                Spacer()
                AppIconButton(symbol: .clearShelf, label: .shelfClear, action: onClear)
                AppIconButton(symbol: .collapseShelf, label: .shelfCollapse, action: onCollapse)
            }
            .frame(height: AppDimensions.Shelf.headerHeight)
            ScrollView {
                LazyVStack(spacing: 0) { tiles() }
            }
        }
        .padding(.horizontal, AppDimensions.Spacing.medium)
        .padding(.vertical, AppDimensions.Spacing.medium)
        .frame(width: AppDimensions.Shelf.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .appGlass(.floating, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
    }
}
