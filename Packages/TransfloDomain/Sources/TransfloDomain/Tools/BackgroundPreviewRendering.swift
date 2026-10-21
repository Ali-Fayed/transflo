import Foundation

/// Strategy for rendering the same background settings on a small, encoded preview image.
public protocol BackgroundPreviewRendering: Sendable {
    func render(_ thumbnail: Data, style: BackgroundStyle) async throws(JobError) -> Data
}
