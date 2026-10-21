import Foundation
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

struct VerificationTools {
    let root: URL
    let fixtures: VerificationFixtures
    private let copier = SpyCopier()

    var engines: [any ToolEngine] {
        [
            ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: MediaToolTests.naming, copier: copier),
            MediaToolEngine(
                ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming
            ),
            PDFToolEngine(naming: MediaToolTests.naming),
            FileToolEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        ]
    }

    func run(report: inout VerificationReport) async throws {
        let catalog = try BundledToolCatalogLoader().load()
        let failedOnly = ProcessInfo.processInfo.environment["TRANSFLO_VERIFICATION_PHASE"] == "failed"
        let failing = Set(report.rows.filter { $0.status == "FAIL" }.map(\.id))
        for tool in catalog.tools {
            for format in MatrixConversionTests.catalog.formats where tool.accepts(format) {
                if failedOnly && !failing.contains("tool-\(tool.kind)-\(format.id)") { continue }
                let sample = [FormatDescriptor?](repeating: format, count: tool.requiresMultipleFiles ? 2 : 1)
                guard let engine = engines.first(where: { $0.canRun(tool.kind, on: sample) }) else {
                    report.append("hidden-\(tool.kind)-\(format.id)", status: "HIDDEN",
                                  detail: "Unavailable on this format; filtered by app capabilities", started: Date())
                    continue
                }
                await exercise(tool.kind, format: format, multiple: tool.requiresMultipleFiles,
                               engine: engine, report: &report)
            }
        }
        let originals = try FileManager.default.contentsOfDirectory(
            at: root.deletingLastPathComponent(), includingPropertiesForKeys: nil
        ).filter { ["png", "pdf"].contains($0.pathExtension.lowercased()) }
        for source in originals {
            guard let format = MatrixConversionTests.catalog.format(forFileExtension: source.pathExtension) else {
                continue
            }
            for tool in catalog.tools where tool.accepts(format) {
                if failedOnly && !failing.contains("real-tool-\(tool.kind)-\(format.id)") { continue }
                let sample = [FormatDescriptor?](repeating: format, count: tool.requiresMultipleFiles ? 2 : 1)
                guard let engine = engines.first(where: { $0.canRun(tool.kind, on: sample) }) else { continue }
                await exercise(tool.kind, format: format, multiple: tool.requiresMultipleFiles,
                               engine: engine, source: source, report: &report)
            }
        }
    }

    private func exercise(
        _ tool: ToolKind,
        format: FormatDescriptor,
        multiple: Bool,
        engine: any ToolEngine,
        source: URL? = nil,
        report: inout VerificationReport
    ) async {
        let id = "\(source == nil ? "tool" : "real-tool")-\(tool)-\(format.id)"
        let started = Date()
        var produced: [URL] = []
        do {
            let directory = try report.directory(id)
            let input = try await copyInput(tool, format: format.id.rawValue, source: source, directory: directory)
            var inputs = [input]
            if multiple {
                let second = directory.appendingPathComponent("second").appendingPathExtension(input.pathExtension)
                try FileManager.default.copyItem(at: input, to: second)
                inputs.append(second)
            }
            let request = ToolRequest(tool: tool, settings: settings(tool, format: format.id.rawValue),
                                      items: inputs.map { ToolItem(url: $0, format: format) })
            let outputs = try await VerificationSupport.timed { try await engine.run(request) { _ in } }
            produced = outputs
            if tool == .readCode {
                guard copier.copied.last == "https://transfloformac.ali-fayed.com/verification" else {
                    throw VerificationSupport.Failure.unreadable("QR payload")
                }
            } else if tool == .rename {
                guard outputs.count == inputs.count,
                      outputs.allSatisfy({ $0.lastPathComponent.hasPrefix("Verified ") }) else {
                    throw VerificationSupport.Failure.unreadable("rename result")
                }
            } else {
                try await VerificationSupport.validate(outputs)
                try await checkEffect(tool, input: input, outputs: outputs, format: format.id.rawValue)
            }
            if tool != .rename {
                guard FileManager.default.fileExists(atPath: input.path) else {
                    throw VerificationSupport.Failure.changedOriginal
                }
            }
            report.append(id, status: "PASS", detail: "Tool completed; output validated",
                          outputs: outputs, started: started)
        } catch JobError.nothingFound where tool == .readCode && source != nil {
            report.append(id, status: "EXPECTED", detail: "No QR/barcode in the original file", started: started)
        } catch JobError.nothingFound where tool == .compress {
            report.append(id, status: "EXPECTED", detail: "Already optimized; refused a larger result",
                          started: started)
        } catch { report.append(id, error: error, outputs: produced, started: started) }
    }

    private func copyInput(_ tool: ToolKind, format: String, source: URL?, directory: URL) async throws -> URL {
        guard let source else { return try await fixtures.toolSource(tool, format: format, directory: directory) }
        let input = directory.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: input)
        return input
    }

    private func settings(_ tool: ToolKind, format: String) -> ToolSettings {
        let image: [ToolKind: ToolSettings] = [
            .resize: .resize(width: 32, height: 24),
            .crop: .crop(NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)),
            .adjust: .adjust(ImageAdjustments(exposure: 0.5, contrast: 1.1, saturation: 0.8)),
            .annotate: .annotate([Annotation(kind: .rectangle,
                points: [UnitPoint(x: 0.1, y: 0.1), UnitPoint(x: 0.8, y: 0.8)], color: "#FF0000", weight: 0.05)]),
            .redact: .redact([NormalizedRect(x: 0.1, y: 0.1, width: 0.4, height: 0.4)]),
            .addBackground: .addBackground(color: "#136F63"),
            .collage: .collage(columns: 2, spacing: 4, background: "#FFFFFF")
        ]
        if let value = image[tool] { return value }
        if tool == .split {
            if format == "pdf" { return .splitPages(every: 1) }
            return .split(points: [0.5])
        }
        let other: [ToolKind: ToolSettings] = [
            .trim: .trim(start: 0.2, end: 0.7), .changeSpeed: .changeSpeed(2), .snapshot: .snapshot(at: 0.5),
            .bleep: .bleep([TimeSpan(start: 0.2, end: 0.5)]), .reorganizePages: .pages([1, 0]),
            .extractPages: .pages([0]),
            .editMetadata: .metadata([.title: "Transflo Verification", .author: "Test Fixture"]),
            .rename: .rename(pattern: "Verified {n}", start: 1)
        ]
        return other[tool] ?? .defaults(for: tool)
    }

    private func checkEffect(_ tool: ToolKind, input: URL, outputs: [URL], format: String) async throws {
        if format == "pdf" { try pdfEffect(tool, input: input, output: outputs[0]) }
        guard let family = MatrixConversionTests.catalog.format(FormatID(format))?.family else { return }
        if family == .image { try imageEffect(tool, input: input, output: outputs[0]) }
        if family == .audio || family == .video {
            let info = try await FFprobe.info(binary: try #require(MediaFixtures.ffprobe), file: outputs[0])
            try mediaEffect(tool, info: info)
        }
    }

    private func pdfEffect(_ tool: ToolKind, input: URL, output: URL) throws {
        let result = try #require(PDFDocument(url: output))
        let original = try #require(PDFDocument(url: input))
        let title = result.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        let checks: [ToolKind: Bool] = [
            .extractPages: result.pageCount == 1,
            .rotate: result.page(at: 0)?.rotation == 90,
            .merge: result.pageCount == original.pageCount * 2,
            .reorganizePages: result.pageCount == 2,
            .editMetadata: title == "Transflo Verification"
        ]
        if checks[tool] == false { throw VerificationSupport.Failure.unreadable("PDF tool effect") }
    }

    private func imageEffect(_ tool: ToolKind, input: URL, output: URL) throws {
        guard [.resize, .crop].contains(tool) else { return }
        let original = try ImageDecoding.decodeUpright(input).image
        let result = try ImageDecoding.decodeUpright(output).image
        let expected = tool == .resize ? (32, 24) : (original.width / 2, original.height / 2)
        guard result.width == expected.0, result.height == expected.1 else {
            throw VerificationSupport.Failure.unreadable("image dimensions")
        }
    }

    private func mediaEffect(_ tool: ToolKind, info: MediaInfo) throws {
        let checks: [ToolKind: Bool] = [
            .mute: info.hasVideo && !info.hasAudio, .channels: info.audioChannels == 1,
            .resize: info.width == 32 && info.height == 24,
            .trim: abs((info.duration ?? 0) - 0.5) < 0.25,
            .changeSpeed: abs((info.duration ?? 0) - 0.5) < 0.3,
            .merge: (info.duration ?? 0) > 1.5, .editMetadata: info.tags["title"] == "Transflo Verification"
        ]
        if checks[tool] == false { throw VerificationSupport.Failure.unreadable("media tool effect") }
    }
}
