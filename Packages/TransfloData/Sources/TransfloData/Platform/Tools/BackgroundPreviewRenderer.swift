import Foundation
import ImageIO
import TransfloDomain

/// Preview adapter: decode and compose off the main actor through the export compositor.
public struct BackgroundPreviewRenderer: BackgroundPreviewRendering {
    public init() {}

    public func render(_ thumbnail: Data, style: BackgroundStyle) async throws(JobError) -> Data {
        try await BlockingWork.runCancellable { isCancelled throws(JobError) in
            if isCancelled() { throw .cancelled }
            guard let source = CGImageSourceCreateWithData(thumbnail as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1024,
                    kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else { throw .failed }
            let composed = try BackgroundComposer.compose(image, style: style)
            if isCancelled() { throw .cancelled }
            return try PNGWriter.data(composed)
        }
    }
}
