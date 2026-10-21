import SwiftUI

/// Thumbnails in a grid with the chosen gap over the chosen backdrop, scaled so every tile fits
/// inside the preview box.
struct AppCollagePreview: View {
    let thumbnails: [Data?]
    let columns: Int
    let spacing: CGFloat
    let backdrop: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: safeColumns),
                  spacing: spacing) {
            ForEach(thumbnails.indices, id: \.self) { index in
                AppPreviewImage(data: thumbnails[index], backdrop: backdrop).aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(spacing)
        .background(backdrop, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.medium))
        .modifier(AppPreviewFrame(aspectRatio: CGFloat(safeColumns) / CGFloat(rows)))
    }

    private var safeColumns: Int { max(columns, 1) }
    private var rows: Int { max(1, (thumbnails.count + safeColumns - 1) / safeColumns) }
}
