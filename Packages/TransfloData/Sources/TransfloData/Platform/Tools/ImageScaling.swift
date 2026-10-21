import CoreGraphics

/// Resampling helpers for image tools.
enum ImageScaling {
    /// `image` scaled so its long edge is at most `longEdge`, or `nil` if it is already that small.
    static func fit(_ image: CGImage, longEdge: Int) -> CGImage? {
        let current = max(image.width, image.height)
        guard current > longEdge else { return nil }
        let scale = Double(longEdge) / Double(current)
        let width = Int(Double(image.width) * scale)
        let height = Int(Double(image.height) * scale)
        return draw(image, width: width, height: height) { context in
            context.draw(image, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
        }
    }

    /// Renders into a new RGBA context of the given size.
    static func draw(_ image: CGImage, width: Int, height: Int, _ body: (CGContext) -> Void) -> CGImage? {
        guard RasterLimits.allows(CGSize(width: width, height: height)), let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        body(context)
        return context.makeImage()
    }

    /// Rotates clockwise by quarter turns, then mirrors.
    static func rotate(_ image: CGImage, quarterTurns: Int, flipHorizontal: Bool, flipVertical: Bool) -> CGImage? {
        let turns = ((quarterTurns % 4) + 4) % 4
        let swaps = turns % 2 == 1
        let width = swaps ? image.height : image.width
        let height = swaps ? image.width : image.height
        return draw(image, width: width, height: height) { context in
            context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
            context.scaleBy(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
            context.rotate(by: -CGFloat(turns) * .pi / 2)
            context.draw(image, in: CGRect(
                x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2,
                width: CGFloat(image.width), height: CGFloat(image.height)
            ))
        }
    }
}
