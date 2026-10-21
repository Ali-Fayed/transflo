import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import TransfloDomain

/// Editor previews for stills on every platform: ImageIO for images, PDFKit for PDFs. Video and
/// audio facts come from the platform's media provider, so frames and waveforms are `nil` here.
public struct StillToolPreviewProvider: ToolPreviewProviding {
    static let thumbnailLongEdge = 900
    static let pageThumbnailLongEdge: CGFloat = 160
    /// Every page thumbnail together stays under this many bytes.
    static let pageThumbnailBudget = 32 * 1024 * 1024

    public init() {}

    public func preview(of url: URL, format: FormatDescriptor?) async -> ToolPreview {
        if format?.family == .image {
            return (try? await BlockingWork.run { () throws(JobError) in try Self.imagePreview(url) }) ?? .empty
        }
        guard format?.id.rawValue == "pdf" else { return .empty }
        return (try? await BlockingWork.run { () throws(JobError) in try Self.pdfPreview(url) }) ?? .empty
    }

    public func frame(of url: URL, at seconds: Double) async -> Data? { nil }

    public func waveform(of url: URL) async -> Data? { nil }

    public func adjusted(_ thumbnail: Data, with adjustments: ImageAdjustments) async -> Data? {
        try? await BlockingWork.run { () throws(JobError) -> Data in
            guard let source = CGImageSourceCreateWithData(thumbnail as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw .failed }
            return try PNGWriter.data(try ImageAdjuster.apply(adjustments, to: image))
        }
    }

    public func pageThumbnails(of url: URL) async -> [Data] {
        (try? await BlockingWork.run { () throws(JobError) -> [Data] in
            let document = try PDFKitEngine.open(url)
            var thumbnails: [Data] = []
            var bytes = 0
            for index in 0..<document.pageCount {
                if BlockingWork.isCancelled { throw .cancelled }
                guard let page = document.page(at: index) else { throw .failed }
                let data = try PNGWriter.data(try Self.render(page, longEdge: Self.pageThumbnailLongEdge))
                bytes += data.count
                guard bytes <= Self.pageThumbnailBudget else { throw .unsupported }
                thumbnails.append(data)
            }
            return thumbnails
        }) ?? []
    }

    public func pagePreview(of url: URL, index: Int) async -> ToolPreview {
        (try? await BlockingWork.run { () throws(JobError) in
            let document = try PDFKitEngine.open(url)
            guard let page = document.page(at: index) else { throw .failed }
            let image = try Self.render(page, longEdge: CGFloat(Self.thumbnailLongEdge))
            return ToolPreview(width: image.width, height: image.height, duration: nil,
                               pageCount: document.pageCount, thumbnail: try PNGWriter.data(image))
        }) ?? .empty
    }

    private static func render(_ page: PDFPage, longEdge: CGFloat) throws(JobError) -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        return try PDFPageImageExporter.render(page, dpi: 72 * longEdge / max(bounds.width, bounds.height, 1))
    }

    private static func imagePreview(_ url: URL) throws(JobError) -> ToolPreview {
        let decoded = try ImageDecoding.decodeUpright(url)
        let thumbnail = ImageScaling.fit(decoded.image, longEdge: thumbnailLongEdge) ?? decoded.image
        return ToolPreview(width: decoded.image.width, height: decoded.image.height, duration: nil, pageCount: nil,
                           thumbnail: try PNGWriter.data(thumbnail))
    }

    private static func pdfPreview(_ url: URL) throws(JobError) -> ToolPreview {
        let document = try PDFKitEngine.open(url)
        let first = try document.page(at: 0).map { page throws(JobError) in
            try PDFPageImageExporter.render(page, dpi: 72)
        }
        return ToolPreview(width: first?.width, height: first?.height, duration: nil, pageCount: document.pageCount,
                           thumbnail: try first.map { image throws(JobError) in try PNGWriter.data(image) })
    }
}
