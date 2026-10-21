import Foundation
import TransfloDomain

/// Width over height of a preview, 1 until its size is known.
enum PreviewAspect {
    static func ratio(_ preview: ToolPreview) -> CGFloat {
        guard let width = preview.width, let height = preview.height, height > 0 else { return 1 }
        return CGFloat(width) / CGFloat(height)
    }
}
