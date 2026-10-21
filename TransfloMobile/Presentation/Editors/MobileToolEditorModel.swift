import AVFoundation
import Foundation
import ImageIO
import Observation
import PDFKit
import TransfloDomain
import UIKit
import UniformTypeIdentifiers

/// Mobile parameters are translated into the same validated settings used by Mac tool runners.
@Observable
final class MobileToolEditorModel {
    /// The editing session owns playback, so sheet transitions cannot recreate its player.
    let playback = MobileMediaPlayback()
    static let supported: Set<ToolKind> = [
        .compress, .resize, .crop, .rotate, .adjust, .removeBackground, .addBackground,
        .collage, .imagesToPDF, .readCode, .removeMetadata, .reorganizePages, .extractPages,
        .merge, .split, .rename, .editMetadata, .trim, .changeSpeed, .snapshot
    ]
    let tool: ToolKind
    let items: [URL]
    var thumbnail: UIImage?
    var width = 1200
    var height = 800
    var keepProportions = true
    var originalWidth = 1200
    var originalHeight = 800
    var turns = 1
    var flipHorizontal = false
    var flipVertical = false
    var cropWidth = 0.8
    var cropHeight = 0.8
    var cropX = 0.5
    var cropY = 0.5
    var brightness = 0.0
    var contrast = 1.0
    var saturation = 1.0
    var compression = 1
    var colorHex = "F5F4EF"
    var columns = 2
    var spacing = 12
    var pattern = "{name}-{n}"
    var start = 1
    var title = ""
    var author = ""
    var pageCount = 0
    var pages: [Int] = []
    var selectedPages: Set<Int> = []
    var pagesPerFile = 1
    /// Audio and video: the source's length and the chosen times, in seconds.
    var duration = 0.0
    var trimStart = 0.0
    var trimEnd = 0.0
    var speed = 2.0
    var snapshotTime = 0.0
    var splitEvery = 30.0
    var loaded = false
    var message: L10nKey?

    init(tool: ToolKind, items: [URL]) {
        self.tool = tool
        self.items = items
    }

    var isVideo: Bool {
        items.first.flatMap { UTType(filenameExtension: $0.pathExtension.lowercased()) }?.conforms(to: .movie) == true
    }
    var isPDF: Bool { items.first?.pathExtension.lowercased() == "pdf" }
    var isAudio: Bool {
        items.first.flatMap { UTType(filenameExtension: $0.pathExtension.lowercased()) }?.conforms(to: .audio) == true
    }
    var isMedia: Bool { isVideo || isAudio }
    var isPageTool: Bool { [.extractPages, .reorganizePages].contains(tool) || (tool == .split && !isMedia) }
    /// Where Split cuts a recording: every `splitEvery` seconds.
    var splitPoints: [Double] {
        guard splitEvery > 0 else { return [] }
        return Array(stride(from: splitEvery, to: duration, by: splitEvery))
    }
    var isValid: Bool {
        guard loaded, message == nil else { return false }
        switch tool {
        case .resize: return (1...16000).contains(width) && (1...16000).contains(height)
            && Double(width) * Double(height) <= 60_000_000
        case .rename:
            return !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !pattern.contains("/") && !pattern.contains(":") && start >= 1
        case .extractPages: return items.count == 1 && !selectedPages.isEmpty
        case .reorganizePages: return items.count == 1 && !pages.isEmpty
        case .split where isMedia: return items.count == 1 && !splitPoints.isEmpty
        case .split: return items.count == 1 && pageCount > pagesPerFile && pagesPerFile > 0
        case .trim: return trimEnd - trimStart >= 0.1
        case .changeSpeed: return (0.25...4).contains(speed) && speed != 1
        case .snapshot: return duration > 0
        case .editMetadata: return !title.isEmpty || !author.isEmpty
        default: return true
        }
    }

    var crop: NormalizedRect {
        NormalizedRect(x: cropX * (1 - cropWidth), y: cropY * (1 - cropHeight),
                       width: cropWidth, height: cropHeight)
    }

    var settings: ToolSettings {
        switch tool {
        case .compress: .compress(compression == 0 ? .light : compression == 2 ? .strong : .medium)
        case .resize: .resize(width: width, height: height)
        case .crop: .crop(crop)
        case .rotate: .rotate(quarterTurns: turns, flipHorizontal: flipHorizontal, flipVertical: flipVertical)
        case .adjust: .adjust(ImageAdjustments(exposure: 0, contrast: contrast,
                                              saturation: saturation, brightness: brightness))
        case .addBackground: .addBackground(color: colorHex)
        case .collage: .collage(columns: columns, spacing: spacing, background: colorHex)
        case .removeMetadata: .removeMetadata(Set(MetadataCategory.allCases))
        case .reorganizePages: .pages(pages)
        case .extractPages: .pages(pages.filter { selectedPages.contains($0) })
        case .split where isMedia: .split(points: splitPoints)
        case .split: .splitPages(every: pagesPerFile)
        case .trim: .trim(start: trimStart, end: trimEnd)
        case .changeSpeed: .changeSpeed(speed)
        case .snapshot: .snapshot(at: snapshotTime)
        case .rename: .rename(pattern: pattern, start: start)
        case .editMetadata: .metadata([.title: title, .author: author])
        default: .none
        }
    }

    var renamed: [String] {
        RenamePattern.names(pattern, originals: items.map { $0.deletingPathExtension().lastPathComponent },
                            start: start)
    }

    func setWidth(_ value: Int) {
        width = value
        if keepProportions { height = max(1, Int(Double(value) * Double(originalHeight) / Double(originalWidth))) }
    }

    func setHeight(_ value: Int) {
        height = value
        if keepProportions { width = max(1, Int(Double(value) * Double(originalWidth) / Double(originalHeight))) }
    }

    func load() async {
        guard !loaded, let url = items.first else { return }
        if isMedia {
            let seconds = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
            duration = seconds.isFinite ? max(0, seconds) : 0
            trimEnd = duration
            splitEvery = max(1, min(30, (duration / 2).rounded(.down)))
            if duration <= 0 { message = .editorPreviewUnavailable }
        }
        if isVideo {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1000, height: 1000)
            if let frame = try? await generator.image(at: .zero) { thumbnail = UIImage(cgImage: frame.image) }
            loaded = true
            return
        }
        if isAudio {
            loaded = true
            return
        }
        // Decode only a bounded thumbnail; the shared runner processes the original on Apply.
        let info = await Task.detached { MobileToolSource.load(url) }.value
        thumbnail = info.image
        if info.width > 0, info.height > 0 {
            width = info.width
            height = info.height
            originalWidth = info.width
            originalHeight = info.height
        }
        pageCount = info.pages
        pages = Array(0..<pageCount)
        selectedPages = Set(pages)
        if isPageTool, !isPDF || items.count != 1 { message = .mobileSinglePDF }
        if isPageTool, pageCount == 0 { message = .editorPreviewUnavailable }
        loaded = true
    }
}

/// Source inspection stays off the UI thread and never decodes a full-resolution photograph.
nonisolated private enum MobileToolSource {
    struct Info: @unchecked Sendable {
        let image: UIImage?
        let width: Int
        let height: Int
        let pages: Int
    }

    static func load(_ url: URL) -> Info {
        if url.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: url) {
            let image = pdf.page(at: 0)?.thumbnail(of: CGSize(width: 800, height: 800), for: .mediaBox)
            return Info(image: image, width: 0, height: 0, pages: pdf.pageCount)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return Info(image: nil, width: 0, height: 0, pages: 0)
        }
        let attributes = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let width = attributes[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = attributes[kCGImagePropertyPixelHeight] as? Int ?? 0
        let orientation = attributes[kCGImagePropertyOrientation] as? Int ?? 1
        let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1000,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary).map { UIImage(cgImage: $0) }
        return Info(image: image, width: orientation >= 5 ? height : width,
                    height: orientation >= 5 ? width : height, pages: 0)
    }
}
