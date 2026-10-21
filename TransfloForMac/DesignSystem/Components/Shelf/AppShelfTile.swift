import SwiftUI

/// One file on the shelf: its Finder icon and name. Drag it out to use the file; ✕ removes it
/// from the shelf (the file itself is untouched).
struct AppShelfTile: View {
    @Environment(Localizer.self) private var localizer
    let url: URL
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.small) {
            HStack(spacing: AppDimensions.Spacing.small) {
                AppFileIcon(url: url)
                AppText(verbatim: url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(localizer.string(.shelfDragHint))
            Spacer(minLength: 0)
            AppIconButton(symbol: .removeFromShelf, label: .shelfRemove, action: onRemove)
        }
        .frame(height: AppDimensions.Shelf.rowHeight)
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .help(url.path)
    }
}
