import SwiftUI

/// A vertical list the user reorders by dragging rows. Items must be unique.
struct AppReorderableList<Item: Hashable, Row: View>: View {
    let items: [Item]
    let onMove: (IndexSet, Int) -> Void
    @ViewBuilder let row: (Item) -> Row
    @State private var rowHeights: [Item: CGFloat] = [:]

    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                row(item)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[item] = $0 }
            }
                .onMove(perform: onMove)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.vertical, AppDimensions.Spacing.xSmall)
        .frame(height: min(AppDimensions.Editor.listHeight,
                           max(44, items.reduce(16) { $0 + (rowHeights[$1] ?? 56) + 16 })))
        .appGlass(.card, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
    }
}
