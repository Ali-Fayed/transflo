import QuickLookThumbnailing
import SwiftUI

/// A file's Quick Look thumbnail (the page, frame or picture itself), or its system icon while the
/// thumbnail loads or when there is none, on a tile with a hairline edge so white pages still read.
struct AppFileThumbnail: View {
    let url: URL
    var size: CGFloat = AppDimensions.Mobile.fileThumbnail
    @Environment(\.displayScale) private var scale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                AppPlatform.fileIcon(for: url).resizable().scaledToFit().padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppDimensions.Radius.small))
        .overlay {
            RoundedRectangle(cornerRadius: AppDimensions.Radius.small)
                .strokeBorder(AppColors.divider, lineWidth: AppDimensions.Stroke.hairline)
        }
        .accessibilityHidden(true)
        .task(id: url) {
            let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size, height: size),
                                                       scale: scale, representationTypes: .thumbnail)
            image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).uiImage
        }
    }
}
