import CoreGraphics
import Foundation
import TransfloDomain

/// Core Graphics composition Strategy shared by preview and full-resolution image export.
enum BackgroundComposer {
    static func compose(_ image: CGImage, style: BackgroundStyle) throws(JobError) -> CGImage {
        let style = style.validated
        let size = style.canvasDimensions(imageWidth: image.width, imageHeight: image.height)
        let canvas = CGSize(width: size.width, height: size.height)
        guard RasterLimits.allows(canvas),
              let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw .unsupported }
        let bounds = CGRect(origin: .zero, size: canvas)
        drawFill(style.fill, in: context, bounds: bounds)
        let imageWidth = Double(image.width)
        let imageHeight = Double(image.height)
        let frame = CGRect(x: (size.width - imageWidth) / 2, y: (size.height - imageHeight) / 2,
                           width: imageWidth, height: imageHeight)
        let shortEdge = Double(min(image.width, image.height))
        let radius = shortEdge * style.corners
        let path = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
        if style.shadow > 0 {
            context.saveGState()
            let strength = style.shadow / 100
            context.setShadow(offset: CGSize(width: 0, height: -shortEdge * 0.02 * strength),
                              blur: shortEdge * 0.08 * strength,
                              color: CGColor(gray: 0, alpha: 0.35 * strength))
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
        }
        context.saveGState()
        context.addPath(path)
        context.clip()
        // Restore the canvas inside the shadow plate, so transparent pixels reveal the fill.
        drawFill(style.fill, in: context, bounds: bounds)
        context.interpolationQuality = .high
        context.draw(image, in: frame)
        context.restoreGState()
        guard let result = context.makeImage() else { throw .failed }
        return result
    }

    private static func drawFill(_ fill: BackgroundStyle.Fill, in context: CGContext, bounds: CGRect) {
        switch fill {
        case .solid(let hex):
            context.setFillColor(color(hex))
            context.fill(bounds)
        case .gradient(let preset):
            let colors = [color(preset.colors.start), color(preset.colors.end)] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors,
                                            locations: [0, 1]) else { return }
            let radians = preset.angleDegrees * .pi / 180
            let deltaX = cos(radians) * bounds.width / 2
            let deltaY = sin(radians) * bounds.height / 2
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: bounds.midX - deltaX, y: bounds.midY - deltaY),
                                       end: CGPoint(x: bounds.midX + deltaX, y: bounds.midY + deltaY),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    private static func color(_ hex: String) -> CGColor {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFFFFFF
        return CGColor(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
                       blue: Double(value & 255) / 255, alpha: 1)
    }
}
