import SwiftUI
import TransfloDomain

/// The preview with a drawing surface laid exactly over the picture.
struct AppMarkupBoard: View {
    let thumbnail: Data?
    /// Width over height of the picture.
    let aspectRatio: CGFloat
    var annotations: [Annotation] = []
    var redactions: [NormalizedRect] = []
    let onBegin: (TransfloDomain.UnitPoint) -> Void
    let onMove: (TransfloDomain.UnitPoint) -> Void
    let onEnd: () -> Void

    var body: some View {
        AppPreviewImage(data: thumbnail)
            .overlay {
                if thumbnail != nil {
                    AppMarkupCanvas(annotations: annotations, redactions: redactions,
                                    onBegin: onBegin, onMove: onMove, onEnd: onEnd)
                }
            }
            .modifier(AppPreviewFrame(aspectRatio: aspectRatio))
            .accessibilityIdentifier("editor.markup.board")
    }
}
