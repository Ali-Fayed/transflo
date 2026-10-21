import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain

/// On-device intelligence tools: Extract Text (a `.txt` beside each file), Describe Image (alt text to
/// the clipboard), Smart Rename and Upscale 2×. Describe Image and Smart Rename need Apple's language
/// model, so they only run where it is available.
public struct IntelligenceToolEngine: ToolEngine {
    static let tools: Set<ToolKind> = [.extractText, .describeImage, .smartRename, .upscale]

    private let understanding: any ImageUnderstanding
    private let writer: any TextWriting
    private let copier: any TextCopying
    private let naming: ToolOutputNaming
    private let files: NameOutputFileUseCase
    private let imageWriter: ImageFileWriter
    private let upscaler: any ImageUpscaling

    public init(
        understanding: any ImageUnderstanding,
        writer: any TextWriting,
        copier: any TextCopying,
        naming: ToolOutputNaming,
        files: NameOutputFileUseCase,
        ffmpeg: URL?
    ) {
        self.init(understanding: understanding, writer: writer, copier: copier, naming: naming, files: files,
                  ffmpeg: ffmpeg, upscaler: Self.defaultUpscaler)
    }

    /// MetalFX where the SDK has it (not the iOS Simulator), Core Image otherwise.
    static var defaultUpscaler: any ImageUpscaling {
        #if canImport(MetalFX)
        MetalFXUpscaler()
        #else
        CoreImageUpscaler()
        #endif
    }

    init(
        understanding: any ImageUnderstanding,
        writer: any TextWriting,
        copier: any TextCopying,
        naming: ToolOutputNaming,
        files: NameOutputFileUseCase,
        ffmpeg: URL?,
        upscaler: any ImageUpscaling
    ) {
        self.understanding = understanding
        self.writer = writer
        self.copier = copier
        self.naming = naming
        self.files = files
        self.imageWriter = ImageFileWriter(ffmpeg: ffmpeg)
        self.upscaler = upscaler
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        guard Self.tools.contains(tool), !formats.isEmpty else { return false }
        let ids = formats.map { $0?.id.rawValue ?? "" }
        let images = ImageToolEngine.editable
        switch tool {
        case .extractText: return ids.allSatisfy { images.contains($0) || $0 == "pdf" }
        case .describeImage: return writer.isAvailable && ids.allSatisfy(images.contains)
        case .smartRename: return writer.isAvailable && ids.allSatisfy { images.contains($0) || $0 == "pdf" }
        default: return ids.allSatisfy { images.contains($0) && imageWriter.canWrite($0) }
        }
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        switch request.tool {
        case .extractText: return try await extractText(request.items, progress: progress)
        case .describeImage: return try await describe(request.items, progress: progress)
        case .smartRename: return try await smartRename(request)
        case .upscale:
            return try await BlockingWork.runCancellable { [self] isCancelled throws(JobError) -> [URL] in
                try upscale(request.items, isCancelled: isCancelled, progress: progress)
            }
        default: throw .unsupported
        }
    }

    private func extractText(_ items: [ToolItem], progress: (Double) -> Void) async throws(JobError) -> [URL] {
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in items.enumerated() {
                if Task.isCancelled { throw .cancelled }
                let text = try await understanding.text(in: item.url)
                if !text.isEmpty {
                    let output = try naming.destination(for: item.url, tool: .extractText, pathExtension: "txt")
                    try OutputFile.write(to: output) { staged throws(JobError) in
                        do { try Data((text + "\n").utf8).write(to: staged) } catch { throw .destinationUnavailable }
                    }
                    outputs.append(output)
                }
                progress(Double(index + 1) / Double(items.count))
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        guard !outputs.isEmpty else { throw .nothingFound }
        return outputs
    }

    /// Copies one description, or one line per file (`name: description`) for several.
    private func describe(_ items: [ToolItem], progress: (Double) -> Void) async throws(JobError) -> [URL] {
        var descriptions: [String] = []
        for (index, item) in items.enumerated() {
            if Task.isCancelled { throw .cancelled }
            let labels = try await understanding.labels(for: item.url)
            let text = try await understanding.text(in: item.url)
            guard !labels.isEmpty || !text.isEmpty else { continue }
            let description = try await writer.altText(labels: labels, text: text)
            if !description.isEmpty {
                descriptions.append(items.count == 1 ? description : "\(item.url.lastPathComponent): \(description)")
            }
            progress(Double(index + 1) / Double(items.count))
        }
        guard !descriptions.isEmpty else { throw .nothingFound }
        copier.copy(descriptions.joined(separator: "\n\n"))
        return []
    }

    /// Applies the names reviewed in the editor; without them (Recipes, Shortcuts), suggests them now.
    private func smartRename(_ request: ToolRequest) async throws(JobError) -> [URL] {
        let urls = request.items.map(\.url)
        let names: [String]
        if case .renameTo(let reviewed) = request.settings {
            guard reviewed.count == urls.count else { throw .unsupported }
            // Reviewed names are sanitized again, except a file's own current name, which is kept as is.
            names = zip(reviewed, urls).map { name, url in
                name == url.deletingPathExtension().lastPathComponent ? name : FileNameSanitizer.sanitize(name)
            }
        } else {
            names = try await SuggestFileNamesUseCase(understanding: understanding, writer: writer).execute(for: urls)
        }
        guard names.count == urls.count, !names.contains(where: \.isEmpty) else { throw .unsupported }
        let files = files
        return try await BlockingWork.runCancellable { isCancelled throws(JobError) -> [URL] in
            try FileRenamer.rename(urls, to: names, naming: files, isCancelled: isCancelled)
        }
    }

    private func upscale(
        _ items: [ToolItem], isCancelled: () -> Bool, progress: (Double) -> Void
    ) throws(JobError) -> [URL] {
        try ToolPreflight.images(items, tool: .upscale)
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in items.enumerated() {
                if isCancelled() { throw .cancelled }
                let format = item.format?.id.rawValue ?? ""
                let decoded = try ImageDecoding.decodeUpright(item.url)
                let target = CGSize(width: decoded.image.width * 2, height: decoded.image.height * 2)
                guard RasterLimits.allows(target) else { throw .unsupported }
                let image = try RasterLimits.withPool { () throws(JobError) -> CGImage in
                    try upscaler.upscale(decoded.image)
                }
                if isCancelled() { throw .cancelled }
                let output = try naming.destination(for: item.url, tool: .upscale)
                try imageWriter.write(image, format: format, quality: 0.92,
                                      properties: Self.resized(decoded.properties, to: target), to: output)
                outputs.append(output)
                progress(Double(index + 1) / Double(items.count))
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    /// The source's metadata with its pixel size updated to the upscaled image.
    static func resized(_ properties: [CFString: Any], to size: CGSize) -> [CFString: Any] {
        var updated = properties
        updated[kCGImagePropertyPixelWidth] = Int(size.width)
        updated[kCGImagePropertyPixelHeight] = Int(size.height)
        if var exif = updated[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = Int(size.width)
            exif[kCGImagePropertyExifPixelYDimension] = Int(size.height)
            updated[kCGImagePropertyExifDictionary] = exif
        }
        return updated
    }
}
