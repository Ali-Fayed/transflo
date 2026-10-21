import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Returns a fixed preview (and page thumbnails) and records frame / adjustment requests.
nonisolated final class FakePreviewProvider: ToolPreviewProviding, @unchecked Sendable {
    private let lock = NSLock()
    private let stored: ToolPreview
    private let delay: Duration
    private let pages: [Data]
    private var frames: [Double] = []
    private var adjustments: [ImageAdjustments] = []

    init(_ preview: ToolPreview, pages: [Data] = [], delay: Duration = .zero) {
        self.delay = delay
        stored = preview
        self.pages = pages
    }

    var requestedFrames: [Double] { lock.withLock { frames } }
    var requestedAdjustments: [ImageAdjustments] { lock.withLock { adjustments } }

    func preview(of url: URL, format: FormatDescriptor?) async -> ToolPreview {
        if delay > .zero { try? await Task.sleep(for: delay) }
        return stored
    }

    func frame(of url: URL, at seconds: Double) async -> Data? {
        lock.withLock { frames.append(seconds) }
        return Data("frame \(seconds)".utf8)
    }

    func adjusted(_ thumbnail: Data, with adjustments: ImageAdjustments) async -> Data? {
        lock.withLock { self.adjustments.append(adjustments) }
        return Data("adjusted".utf8)
    }

    func pageThumbnails(of url: URL) async -> [Data] {
        pages
    }
}
