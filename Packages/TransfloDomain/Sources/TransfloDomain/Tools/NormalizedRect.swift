/// A rectangle in unit coordinates (0...1) with its origin at the top-left, independent of
/// pixel size, so one crop applies to an image or to every frame of a video.
public struct NormalizedRect: Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    /// Clamps the rectangle inside the unit square; a minimum size keeps it usable.
    public init(x: Double, y: Double, width: Double, height: Double, minimumSize: Double = 0.01) {
        let minimum = minimumSize.isFinite ? min(1, max(0.000000001, minimumSize)) : 0.01
        let width = width.isFinite ? width : 1
        let height = height.isFinite ? height : 1
        let x = x.isFinite ? x : 0
        let y = y.isFinite ? y : 0
        let clampedWidth = min(max(width, minimum), 1)
        let clampedHeight = min(max(height, minimum), 1)
        self.x = min(max(x, 0), 1 - clampedWidth)
        self.y = min(max(y, 0), 1 - clampedHeight)
        self.width = clampedWidth
        self.height = clampedHeight
    }

    public static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)

    /// The pixel rectangle for an image of the given size, rounded to whole (even, if asked) pixels.
    public func pixels(width imageWidth: Int, height imageHeight: Int, even: Bool = false) -> PixelRect {
        func round(_ value: Double) -> Int {
            let rounded = Int(value.rounded())
            return even ? rounded - rounded % 2 : rounded
        }
        let pixelWidth = max(even ? 2 : 1, round(width * Double(imageWidth)))
        let pixelHeight = max(even ? 2 : 1, round(height * Double(imageHeight)))
        let pixelX = min(round(x * Double(imageWidth)), imageWidth - pixelWidth)
        let pixelY = min(round(y * Double(imageHeight)), imageHeight - pixelHeight)
        return PixelRect(x: max(pixelX, 0), y: max(pixelY, 0), width: pixelWidth, height: pixelHeight)
    }
}
