import Foundation
import ImageIO
import PDFKit
import TransfloDomain

/// Reads title / author / comment from the same places the writers put them: IPTC and TIFF for
/// images, document attributes for PDFs, container tags (via ffprobe) for audio and video.
public struct FileMetadataReader: ToolMetadataReading {
    private let ffprobe: URL?

    public init(ffprobe: URL?) {
        self.ffprobe = ffprobe
    }

    public func metadata(of url: URL, format: FormatDescriptor?) async -> [MetadataField: String] {
        let values: [MetadataField: String?]
        switch format?.family {
        case .image:
            values = (try? await BlockingWork.run { () throws(JobError) in Self.image(url) }) ?? [:]
        case .video, .audio:
            #if os(macOS)
            guard let ffprobe, let info = try? await FFprobe.info(binary: ffprobe, file: url) else { return [:] }
            values = [.title: info.tags["title"], .author: info.tags["artist"], .comment: info.tags["comment"]]
            #else
            return [:]
            #endif
        default:
            guard format?.id.rawValue == "pdf" else { return [:] }
            values = (try? await BlockingWork.run { () throws(JobError) in try Self.pdf(url) }) ?? [:]
        }
        return values.compactMapValues { $0 }.filter { !$0.value.isEmpty }
    }

    private static func image(_ url: URL) -> [MetadataField: String?] {
        let properties = CGImageSourceCreateWithURL(url as CFURL, nil)
            .flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] } ?? [:]
        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let byline = (iptc[kCGImagePropertyIPTCByline] as? [String])?.first
        return [
            .title: iptc[kCGImagePropertyIPTCObjectName] as? String,
            .author: byline ?? tiff[kCGImagePropertyTIFFArtist] as? String,
            .comment: iptc[kCGImagePropertyIPTCCaptionAbstract] as? String
                ?? tiff[kCGImagePropertyTIFFImageDescription] as? String
        ]
    }

    private static func pdf(_ url: URL) throws(JobError) -> [MetadataField: String?] {
        let attributes = try PDFKitEngine.open(url).documentAttributes ?? [:]
        return [
            .title: attributes[PDFDocumentAttribute.titleAttribute] as? String,
            .author: attributes[PDFDocumentAttribute.authorAttribute] as? String,
            .comment: attributes[PDFDocumentAttribute.subjectAttribute] as? String
        ]
    }
}
