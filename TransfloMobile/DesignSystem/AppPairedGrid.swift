import SwiftUI

/// Lays items out two to a row; an odd last item takes the whole row, so the grid ends flush
/// instead of leaving a gap at the bottom.
struct AppPairedGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var spacing: CGFloat = AppDimensions.Spacing.medium
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
                HStack(spacing: spacing) {
                    ForEach(items[start..<min(start + 2, items.count)]) { item in
                        content(item).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
