import Foundation

/// Facts and a thumbnail an editor needs to show a file.
public struct ToolPreview: Sendable, Equatable {
    public let width: Int?
    public let height: Int?
    /// Seconds, for audio and video.
    public let duration: Double?
    public let frameRate: Double?
    public let pageCount: Int?
    /// PNG data of an upright still (image, a video frame, or a PDF's first page).
    public let thumbnail: Data?

    public init(
        width: Int?,
        height: Int?,
        duration: Double?,
        pageCount: Int?,
        thumbnail: Data?,
        frameRate: Double? = nil
    ) {
        self.width = width
        self.height = height
        self.duration = duration
        self.frameRate = frameRate
        self.pageCount = pageCount
        self.thumbnail = thumbnail
    }

    public static let empty = ToolPreview(width: nil, height: nil, duration: nil, pageCount: nil, thumbnail: nil)
}
