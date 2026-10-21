import CoreGraphics
import Foundation
import TransfloDomain

/// Image tools: Compress, Rotate & flip, Resize, Crop, Adjust, Remove metadata,
/// Remove background, Read QR / barcode (images and PDF) and Images → PDF.
public struct ImageToolEngine: ToolEngine {
    static let editable: Set<String> = ["jpg", "png", "heic", "tiff", "bmp", "webp", "avif", "gif"]
    static let tools: Set<ToolKind> = [
        .compress, .rotate, .resize, .crop, .adjust, .removeMetadata, .removeBackground, .readCode, .imagesToPDF,
        .annotate, .redact, .addBackground, .collage, .editMetadata
    ]

    private let writer: ImageFileWriter
    private let naming: ToolOutputNaming
    private let copier: any TextCopying

    public init(ffmpeg: URL?, naming: ToolOutputNaming, copier: any TextCopying) {
        self.writer = ImageFileWriter(ffmpeg: ffmpeg)
        self.naming = naming
        self.copier = copier
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        guard Self.tools.contains(tool), !formats.isEmpty else { return false }
        let ids = formats.map { $0?.id.rawValue ?? "" }
        switch tool {
        case .readCode:
            return ids.allSatisfy { Self.editable.contains($0) || $0 == "pdf" }
        case .removeBackground:
            // The result is PNG; availability must not depend on an encoder for the input format.
            return ids.allSatisfy(Self.editable.contains)
        case .imagesToPDF, .collage:
            return ids.count >= 2 && ids.allSatisfy(Self.editable.contains)
        case .editMetadata:
            // BMP has no IPTC/TIFF fields; ImageIO silently drops the editor's title and author.
            return ids.allSatisfy { Self.editable.contains($0) && !["webp", "bmp"].contains($0)
                && writer.canWrite($0) }
        case .compress:
            return ids.allSatisfy { ImageCompressor.compressible.contains($0) && writer.canWrite($0) }
        default:
            return ids.allSatisfy { Self.editable.contains($0) && writer.canWrite($0) }
        }
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        try await BlockingWork.runCancellable { [self] isCancelled throws(JobError) -> [URL] in
            try ToolPreflight.images(request.items, tool: request.tool)
            switch request.tool {
            case .readCode:
                if case .copyCodes(let codes) = request.settings {
                    guard !codes.isEmpty else { throw .nothingFound }
                    copier.copy(codes.joined(separator: "\n"))
                    return []
                }
                return try readCodes(request.items, isCancelled: isCancelled)
            case .imagesToPDF:
                if case .assemble(let assembly) = request.settings {
                    guard let items = assembly.ordered(request.items) else { throw .unsupported }
                    return try imagesToPDF(items, layout: assembly, isCancelled: isCancelled)
                }
                return try imagesToPDF(request.items, isCancelled: isCancelled)
            case .collage:
                if case .collageLayout(let settings) = request.settings, let first = request.items.first {
                    let image = try CollageRenderer.render(request.items.map(\.url), settings: settings)
                    if isCancelled() { throw .cancelled }
                    let output = try naming.destination(for: first.url, tool: .collage, pathExtension: "png")
                    try PNGWriter.write(image, to: output)
                    return [output]
                }
                return try collage(request.items, settings: request.settings, isCancelled: isCancelled)
            default:
                return try perFile(request, isCancelled: isCancelled, progress: progress)
            }
        }
    }

    private func perFile(
        _ request: ToolRequest, isCancelled: () -> Bool, progress: (Double) -> Void
    ) throws(JobError) -> [URL] {
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in request.items.enumerated() {
                if isCancelled() { throw .cancelled }
                outputs.append(try apply(request.tool, settings: request.settings, to: item, isCancelled: isCancelled))
                progress(Double(index + 1) / Double(request.items.count))
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    private func apply(
        _ tool: ToolKind, settings: ToolSettings, to item: ToolItem, isCancelled: () -> Bool
    ) throws(JobError) -> URL {
        let format = item.format?.id.rawValue ?? ""
        // WebP is encoded by ffmpeg, whose image path does not persist these ImageIO tags.
        if tool == .editMetadata && format == "webp" { throw .unsupported }
        let output = try naming.destination(
            for: item.url, tool: tool, pathExtension: tool == .removeBackground ? "png" : nil
        )
        do throws(JobError) {
            switch (tool, settings) {
            case (.compress, _):
                try ImageCompressionHandler.write(item, settings: settings,
                                                  writer: writer, to: output, isCancelled: isCancelled)
            case (.removeMetadata, let settings):
                let decoded = try ImageDecoding.decodeUpright(item.url)
                let categories: Set<MetadataCategory>
                if case .removeMetadata(let selected) = settings { categories = selected } else {
                    categories = Set(MetadataCategory.allCases)
                }
                try writer.write(decoded.image, format: format,
                                 properties: MetadataFiltering.image(decoded.properties, removing: categories),
                                 to: output)
            case let (.editMetadata, .metadata(values)):
                let decoded = try ImageDecoding.decodeUpright(item.url)
                let properties = ImageMetadataWriter.properties(decoded.properties, applying: values)
                try writer.write(decoded.image, format: format, properties: properties, to: output)
            case (.removeBackground, _):
                let original = try ImageDecoding.decodeUpright(item.url).image
                let options: BackgroundRemovalSettings
                if case .removeBackground(let settings) = settings { options = settings } else {
                    options = BackgroundRemovalSettings()
                }
                try PNGWriter.write(try VisionImageTools.removingBackground(from: original, settings: options).image,
                                    to: output)
            default:
                let decoded = try ImageDecoding.decodeUpright(item.url)
                let image = try edited(decoded.image, settings: settings)
                try writer.write(image, format: format, properties: decoded.properties, to: output)
            }
        } catch JobError.destinationOccupied {
            throw .destinationOccupied
        } catch {
            throw error
        }
        return output
    }

    /// Pixel edits that keep the file's format and metadata: rotate, resize, crop, adjust.
    private func edited(_ image: CGImage, settings: ToolSettings) throws(JobError) -> CGImage {
        let result: CGImage? = switch settings {
        case let .rotate(turns, flipH, flipV):
            ImageScaling.rotate(image, quarterTurns: turns, flipHorizontal: flipH, flipVertical: flipV)
        case let .resize(width, height) where width > 0 && height > 0:
            ImageScaling.draw(image, width: width, height: height) {
                $0.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        case let .crop(rect):
            image.cropping(to: Self.frame(rect.pixels(width: image.width, height: image.height)))
        case let .adjust(adjustments):
            try ImageAdjuster.apply(adjustments, to: image)
        case let .annotate(annotations):
            ImageMarkup.annotate(image, with: annotations)
        case let .redact(boxes):
            ImageMarkup.redact(image, boxes: boxes)
        case let .addBackground(style):
            try BackgroundComposer.compose(image, style: style)
        default:
            throw .unsupported
        }
        guard let result else { throw .failed }
        return result
    }

    private static func frame(_ pixels: PixelRect) -> CGRect {
        CGRect(x: pixels.x, y: pixels.y, width: pixels.width, height: pixels.height)
    }

    private func readCodes(_ items: [ToolItem], isCancelled: () -> Bool) throws(JobError) -> [URL] {
        var codes: [String] = []
        for item in items {
            if isCancelled() { throw .cancelled }
            let found = try RasterLimits.withPool { () throws(JobError) -> [String] in
                if item.format?.id.rawValue == "pdf" {
                    return try VisionImageTools.codes(inPDF: item.url, isCancelled: isCancelled)
                }
                #if os(iOS)
                let image = try ImageDecoding.decodeUpright(item.url, longEdge: 3200).image
                #else
                let image = try ImageDecoding.decodeUpright(item.url).image
                #endif
                return VisionImageTools.codes(in: [image])
            }
            for code in found where !codes.contains(code) { codes.append(code) }
        }
        if isCancelled() { throw .cancelled }
        guard !codes.isEmpty else { throw .nothingFound }
        copier.copy(codes.joined(separator: "\n"))
        return []
    }

    private func collage(
        _ items: [ToolItem], settings: ToolSettings, isCancelled: () -> Bool
    ) throws(JobError) -> [URL] {
        guard case let .collage(columns, spacing, background) = settings, let first = items.first else {
            throw .unsupported
        }
        if isCancelled() { throw .cancelled }
        let image = try ImageDecoding.decodeUpright(first.url, longEdge: 1200).image
        let grid = try ImageMarkup.collage(first: image, layout: (columns, spacing),
                                          background: background, count: items.count) { index throws(JobError) in
            if isCancelled() { throw .cancelled }
            return try ImageDecoding.decodeUpright(items[index].url, longEdge: 1200).image
        }
        if isCancelled() { throw .cancelled }
        let output = try naming.destination(for: first.url, tool: .collage, pathExtension: "png")
        do throws(JobError) {
            try PNGWriter.write(grid, to: output)
            return [output]
        } catch {
            throw error
        }
    }

    private func imagesToPDF(
        _ items: [ToolItem], layout: AssemblySettings? = nil, isCancelled: () -> Bool
    ) throws(JobError) -> [URL] {
        guard let first = items.first else { throw .failed }
        if isCancelled() { throw .cancelled }
        let output = try naming.destination(for: first.url, tool: .imagesToPDF, pathExtension: "pdf")
        try OutputFile.write(to: output) { staged throws(JobError) in
            try writePDF(items, layout: layout, to: staged, isCancelled: isCancelled)
        }
        return [output]
    }

    private func writePDF(
        _ items: [ToolItem], layout: AssemblySettings?, to output: URL, isCancelled: () -> Bool
    ) throws(JobError) {
        var mediaBox = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard let context = CGContext(output as CFURL, mediaBox: &mediaBox, nil) else { throw .destinationUnavailable }
        do throws(JobError) {
            for item in items {
                if isCancelled() { throw .cancelled }
                try RasterLimits.withPool { () throws(JobError) in
                    let page = try ImageDecoding.decodeUpright(item.url)
                    let size = layout?.pageSize(original: page.pointSize) ?? page.pointSize
                    var box = CGRect(origin: .zero, size: size)
                    let info = [kCGPDFContextMediaBox as String: Data(bytes: &box, count: MemoryLayout<CGRect>.size)]
                    context.beginPDFPage(info as CFDictionary)
                    let margin = layout?.margin ?? 0
                    let content = box.insetBy(dx: min(margin, box.width / 3), dy: min(margin, box.height / 3))
                    let placement = layout ?? AssemblySettings(order: [], margin: 0)
                    let imageSize = CGSize(width: page.image.width, height: page.image.height)
                    context.saveGState()
                    context.clip(to: content)
                    context.draw(page.image, in: placement.imageFrame(image: imageSize, page: size))
                    context.restoreGState()
                    context.endPDFPage()
                }
            }
            if isCancelled() { throw .cancelled }
            context.closePDF()
        } catch {
            context.closePDF()
            throw error
        }
    }
}
