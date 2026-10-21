import CoreGraphics
import Foundation
import TransfloDomain

enum CollageRenderer {
    static func render(_ items: [URL], settings: CollageSettings, preview: Bool = false) throws(JobError) -> CGImage {
        guard settings.isValid, settings.order.allSatisfy(items.indices.contains) else { throw .unsupported }
        let full = CGSize(width: settings.outputWidth, height: settings.outputHeight)
        guard RasterLimits.allows(full) else { throw .unsupported }
        let scale = preview ? min(1, 900 / max(full.width, full.height)) : 1
        let size = CGSize(width: max(1, (full.width * scale).rounded()),
                          height: max(1, (full.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw .failed }
        context.interpolationQuality = .high
        context.setFillColor(ImageMarkup.color(settings.background))
        context.fill(CGRect(origin: .zero, size: size))
        let gap = CGFloat(settings.spacing) * scale
        let cell = CGSize(width: CGFloat(settings.cellWidth) * scale, height: CGFloat(settings.cellHeight) * scale)
        for (position, index) in settings.order.enumerated() {
            if BlockingWork.isCancelled { throw .cancelled }
            try RasterLimits.withPool { () throws(JobError) in
                let edge = max(1, Int(max(cell.width, cell.height).rounded(.up)))
                let image = try ImageDecoding.decodeUpright(items[index], longEdge: edge).image
                let slot = CGRect(x: gap + CGFloat(position % settings.columns) * (cell.width + gap),
                    y: size.height - gap - CGFloat(position / settings.columns + 1) * cell.height
                        - CGFloat(position / settings.columns) * gap, width: cell.width, height: cell.height)
                let scaleX = slot.width / CGFloat(image.width)
                let scaleY = slot.height / CGFloat(image.height)
                let fit = settings.fill ? max(scaleX, scaleY) : min(scaleX, scaleY)
                let width = CGFloat(image.width) * fit
                let height = CGFloat(image.height) * fit
                context.saveGState(); context.clip(to: slot)
                context.draw(image, in: CGRect(x: slot.midX - width / 2, y: slot.midY - height / 2,
                                               width: width, height: height))
                context.restoreGState()
            }
        }
        guard let image = context.makeImage() else { throw .failed }
        return image
    }
}
