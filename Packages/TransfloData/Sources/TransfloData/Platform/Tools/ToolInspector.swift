import Foundation
import ImageIO
import PDFKit
import TransfloDomain

public struct ToolInspector: ToolInspectionProviding {
    private let formats: ConversionCatalog
    private let ffmpeg: URL?
    private let ffprobe: URL?

    public init(formats: ConversionCatalog, ffmpeg: URL?, ffprobe: URL?) {
        self.formats = formats; self.ffmpeg = ffmpeg; self.ffprobe = ffprobe
    }

    public func collage(items: [URL], settings: CollageSettings) async throws(JobError) -> Data {
        try await BlockingWork.run { () throws(JobError) in
            try PNGWriter.data(CollageRenderer.render(items, settings: settings, preview: true))
        }
    }

    public func codes(in items: [URL]) async throws(JobError) -> [String] {
        try await BlockingWork.runCancellable { isCancelled throws(JobError) in
            var found: [String] = []
            for url in items {
                if isCancelled() { throw .cancelled }
                let codes: [String]
                if url.pathExtension.lowercased() == "pdf" {
                    codes = try VisionImageTools.codes(inPDF: url, isCancelled: isCancelled)
                } else {
                    codes = VisionImageTools.codes(in: [try ImageDecoding.decodeUpright(url).image])
                }
                for code in codes where !found.contains(code) { found.append(code) }
            }
            return found
        }
    }

    public func background(of item: URL, settings: BackgroundRemovalSettings) async throws(JobError)
        -> BackgroundRemovalPreview {
        try await BlockingWork.runCancellable { isCancelled throws(JobError) in
            try ToolPreflight.images([ToolItem(url: item, format: nil)], tool: .removeBackground)
            let source = try ImageDecoding.decodeUpright(item).image
            let result = try VisionImageTools.removingBackground(from: source, settings: settings)
            if isCancelled() { throw .cancelled }
            let small = ImageScaling.fit(result.image, longEdge: 900) ?? result.image
            return BackgroundRemovalPreview(thumbnail: try PNGWriter.data(small), subjects: result.subjects)
        }
    }

    public func loudness(of item: URL, settings: LoudnessSettings) async throws(JobError) -> LoudnessMeasurement {
        // ffmpeg runs only on the Mac; iPhone and iPad have no loudness tools.
        #if os(macOS)
        guard let ffmpeg else { throw .unsupported }
        return try await LoudnessProcessor.measure(item, target: settings, ffmpeg: ffmpeg)
        #else
        throw .unsupported
        #endif
    }

    public func metadata(in item: URL) async throws(JobError) -> [MetadataEntry] {
        if formats.format(forFileExtension: item.pathExtension)?.family == .image {
            return try await BlockingWork.run { () throws(JobError) in
                guard let source = CGImageSourceCreateWithURL(item as CFURL, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
                    throw .failed
                }
                return MetadataFiltering.entries(properties)
            }
        }
        if item.pathExtension.lowercased() == "pdf" {
            return try await BlockingWork.run { () throws(JobError) in
                let document = try PDFKitEngine.open(item)
                return (document.documentAttributes ?? [:]).map {
                    MetadataEntry(name: String(describing: $0.key), value: String(describing: $0.value),
                                  category: MetadataFiltering.category(String(describing: $0.key)))
                }.sorted { $0.name < $1.name }
            }
        }
        #if os(macOS)
        guard let ffprobe else { throw .unsupported }
        return try await FFprobe.info(binary: ffprobe, file: item).tags.map {
            MetadataEntry(name: $0.key, value: $0.value, category: MetadataFiltering.category($0.key))
        }.sorted { $0.name < $1.name }
        #else
        throw .unsupported
        #endif
    }

    public func audioPreview(of item: URL, settings: ToolSettings) async throws(JobError) -> Data {
        #if os(macOS)
        guard let ffmpeg else { throw .unsupported }
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let output = workspace.url.appendingPathComponent("audition.wav")
        let filters: [String]
        switch settings {
        case .normalize(let target):
            let measured = try await LoudnessProcessor.measure(item, target: target, ffmpeg: ffmpeg)
            guard let arguments = LoudnessProcessor.arguments(target, measured: measured, format: "wav"),
                  let filterIndex = arguments.firstIndex(of: "-af") else { throw .failed }
            filters = ["-af", arguments[filterIndex + 1]]
        case .channels(let mix):
            if mix == .mix { filters = ["-ac", "1"] } else {
                var channel = 0
                if mix == .right { channel = 1 }
                filters = ["-af", "pan=mono|c0=c\(channel)"]
            }
        default: throw .unsupported
        }
        try await validate(settings, tool: .channels, items: [item])
        let status = await ProcessRunner.run(executable: ffmpeg,
            arguments: ["-hide_banner", "-nostdin", "-loglevel", "error", "-i", item.path, "-t", "15", "-vn"]
                + filters + ["-ar", "48000", "-c:a", "pcm_s16le", output.path],
            onStdoutLine: { _ in }, onStderrLine: { _ in })
        if Task.isCancelled { throw .cancelled }
        guard status == 0, let data = try? Data(contentsOf: output) else { throw .failed }
        return data
        #else
        throw .unsupported
        #endif
    }

    public func validate(_ settings: ToolSettings, tool: ToolKind, items: [URL]) async throws(JobError) {
        let mapped = items.map { ToolItem(url: $0, format: formats.format(forFileExtension: $0.pathExtension)) }
        if mapped.allSatisfy({ $0.format?.family == .image }) {
            try await BlockingWork.run { () throws(JobError) in try ToolPreflight.images(mapped, tool: tool) }
        } else if mapped.allSatisfy({ $0.format?.id.rawValue == "pdf" }) {
            try await BlockingWork.run { () throws(JobError) in try ToolPreflight.pdfs(mapped, settings: settings) }
        } else if mapped.allSatisfy({ [.audio, .video].contains($0.format?.family) }) {
            try await ToolPreflight.media(mapped, settings: settings, ffprobe: ffprobe)
        }
    }
}
