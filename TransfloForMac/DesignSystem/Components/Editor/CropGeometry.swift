import TransfloDomain

/// Pure crop-box math for `AppCropOverlay` (moved or resized from a starting rect).
enum CropGeometry {
    static func proposal(from start: NormalizedRect, corner: AppCropOverlay.Corner?, deltaX: Double, deltaY: Double)
        -> NormalizedRect {
        guard let corner else {
            return NormalizedRect(x: start.x + deltaX, y: start.y + deltaY, width: start.width, height: start.height)
        }
        var left = start.x
        var top = start.y
        var right = start.x + start.width
        var bottom = start.y + start.height
        switch corner {
        case .topLeading: left += deltaX; top += deltaY
        case .topTrailing: right += deltaX; top += deltaY
        case .bottomLeading: left += deltaX; bottom += deltaY
        case .bottomTrailing: right += deltaX; bottom += deltaY
        }
        return NormalizedRect(
            x: min(left, right), y: min(top, bottom), width: abs(right - left), height: abs(bottom - top)
        )
    }
}
