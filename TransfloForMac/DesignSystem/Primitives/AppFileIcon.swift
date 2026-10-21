import SwiftUI

/// A file's system icon (Finder's on the Mac).
struct AppFileIcon: View {
    let url: URL

    var body: some View {
        AppPlatform.fileIcon(for: url)
            .resizable()
            .interpolation(.high)
            .frame(width: AppDimensions.Shelf.iconSize, height: AppDimensions.Shelf.iconSize)
            .accessibilityHidden(true)
    }
}
