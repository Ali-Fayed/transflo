import CoreGraphics

/// The shelf panel's size: a header plus one row per file (scrolling past `maxVisibleRows`), or a
/// small pill when collapsed. Includes the clear margin around the glass.
enum ShelfLayout {
    static func size(itemCount: Int, collapsed: Bool) -> CGSize {
        let margin = AppDimensions.Wheel.margin * 2
        guard !collapsed else {
            return CGSize(width: AppDimensions.Shelf.collapsedSize + margin,
                          height: AppDimensions.Shelf.collapsedSize + margin)
        }
        let rows = CGFloat(min(max(itemCount, 1), AppDimensions.Shelf.maxVisibleRows))
        let height = AppDimensions.Shelf.headerHeight + rows * AppDimensions.Shelf.rowHeight
            + AppDimensions.Spacing.medium * 2
        return CGSize(width: AppDimensions.Shelf.width + margin, height: height + margin)
    }
}
