import SwiftUI

/// Sizes a picture preview to its shape inside the editor's fixed preview box, whatever the
/// picture's pixel size (a tiny image still fills the box instead of shrinking to its own size).
struct AppPreviewFrame: ViewModifier {
    /// Width over height of the picture.
    let aspectRatio: CGFloat

    func body(content: Content) -> some View {
        content
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: AppDimensions.Editor.previewHeight)
    }
}
