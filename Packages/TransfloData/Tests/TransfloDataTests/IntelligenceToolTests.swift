import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

/// Counts upscales and doubles the image with Core Image.
private final class SpyUpscaler: ImageUpscaling, @unchecked Sendable {
    // @unchecked: all mutable state is guarded by `lock`.
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.withLock { count } }

    func upscale(_ image: CGImage) throws(JobError) -> CGImage {
        lock.withLock { count += 1 }
        return try CoreImageUpscaler().upscale(image)
    }
}

@Suite("Intelligence tools")
struct IntelligenceToolTests {
    private let catalog = MatrixConversionTests.catalog
    private let copier = SpyTextCopier()
    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("intelligence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func engine(
        _ understanding: StubImageUnderstanding = StubImageUnderstanding(labels: ["dog"], text: "Hello"),
        writer: StubTextWriter = StubTextWriter(),
        upscaler: any ImageUpscaling = SpyUpscaler()
    ) -> IntelligenceToolEngine {
        let files = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        return IntelligenceToolEngine(
            understanding: understanding, writer: writer, copier: copier,
            naming: ToolOutputNaming(naming: files, suffixes: StubToolSuffixes()),
            files: files, ffmpeg: nil, upscaler: upscaler
        )
    }

    private func image(_ name: String = "photo") throws -> URL {
        let url = folder.appendingPathComponent("\(name).png")
        try MediaFixtures.writeImage("png", to: url)
        return url
    }

    private func run(
        _ engine: IntelligenceToolEngine, _ tool: ToolKind, _ urls: [URL], settings: ToolSettings = .none
    ) async throws -> [URL] {
        let items = urls.map { ToolItem(url: $0, format: catalog.format(forFileExtension: $0.pathExtension)) }
        return try await engine.run(ToolRequest(tool: tool, settings: settings, items: items)) { _ in }
    }

    private func formats(_ ids: [String]) -> [FormatDescriptor?] {
        ids.map { catalog.format(forFileExtension: $0) }
    }

    // MARK: Availability

    @Test func languageModelToolsHideWithoutAppleIntelligence() {
        let unavailable = engine(writer: StubTextWriter(isAvailable: false))
        #expect(!unavailable.canRun(.describeImage, on: formats(["jpg"])))
        #expect(!unavailable.canRun(.smartRename, on: formats(["jpg"])))
        #expect(unavailable.canRun(.extractText, on: formats(["jpg", "pdf"])))
        #expect(unavailable.canRun(.upscale, on: formats(["png"])))
    }

    @Test func toolsAcceptOnlyTheirFormats() {
        let available = engine()
        #expect(available.canRun(.describeImage, on: formats(["heic"])))
        #expect(!available.canRun(.describeImage, on: formats(["pdf"])))
        #expect(available.canRun(.smartRename, on: formats(["pdf", "jpg"])))
        #expect(!available.canRun(.upscale, on: formats(["pdf"])))
        #expect(!available.canRun(.extractText, on: formats(["mp4"])))
        #expect(!available.canRun(.extractText, on: []))
        #expect(!available.canRun(.compress, on: formats(["png"])))
    }

    // MARK: Extract Text

    @Test func extractTextWritesATextFileBesideEachImage() async throws {
        let source = try image()
        let outputs = try await run(engine(), .extractText, [source])
        #expect(outputs.map(\.lastPathComponent) == ["photo (extractText).txt"])
        #expect(try String(contentsOf: try #require(outputs.first), encoding: .utf8) == "Hello\n")
    }

    @Test func extractTextSkipsFilesWithoutText() async throws {
        let blank = try image("blank"), words = try image("words")
        let understanding = StubImageUnderstanding(textByName: ["words.png": "Menu"])
        let outputs = try await run(engine(understanding), .extractText, [blank, words])
        #expect(outputs.map(\.lastPathComponent) == ["words (extractText).txt"])
    }

    @Test func extractTextWithNoTextAnywhereFindsNothing() async throws {
        let source = try image()
        await #expect(throws: JobError.nothingFound) {
            try await run(engine(StubImageUnderstanding()), .extractText, [source])
        }
    }

    @Test func extractTextReportsRecognitionFailure() async throws {
        let source = try image()
        await #expect(throws: JobError.failed) {
            try await run(engine(StubImageUnderstanding(error: .failed)), .extractText, [source])
        }
    }

    // MARK: Describe Image

    @Test func describeCopiesAltTextForOneImage() async throws {
        let outputs = try await run(engine(), .describeImage, [try image()])
        #expect(outputs.isEmpty)
        #expect(copier.copied == ["A dog on a beach."])
    }

    @Test func describeLabelsEachLineForSeveralImages() async throws {
        _ = try await run(engine(), .describeImage, [try image("one"), try image("two")])
        #expect(copier.copied == ["one.png: A dog on a beach.\n\ntwo.png: A dog on a beach."])
    }

    @Test func describeWithNothingRecognizedCopiesNothing() async throws {
        let source = try image()
        await #expect(throws: JobError.nothingFound) {
            try await run(engine(StubImageUnderstanding()), .describeImage, [source])
        }
        #expect(copier.copied.isEmpty)
    }

    @Test func describeReportsModelFailure() async throws {
        let source = try image()
        await #expect(throws: JobError.failed) {
            try await run(engine(writer: StubTextWriter(error: .failed)), .describeImage, [source])
        }
        #expect(copier.copied.isEmpty)
    }

    // MARK: Smart Rename

    @Test func smartRenameAppliesReviewedNames() async throws {
        let first = try image("IMG_1"), second = try image("IMG_2")
        let outputs = try await run(engine(), .smartRename, [first, second],
                                    settings: .renameTo(["Beach Day", "receipt"]))
        #expect(outputs.map(\.lastPathComponent) == ["beach-day.png", "receipt.png"])
        #expect(!FileManager.default.fileExists(atPath: first.path))
    }

    @Test func smartRenameWithoutReviewSuggestsNames() async throws {
        let outputs = try await run(engine(writer: StubTextWriter(names: ["Golden Dog"])), .smartRename,
                                    [try image("IMG_1")])
        #expect(outputs.map(\.lastPathComponent) == ["golden-dog.png"])
    }

    @Test func smartRenameRefusesMismatchedOrEmptyNames() async throws {
        let source = try image("IMG_1")
        await #expect(throws: JobError.unsupported) {
            try await run(engine(), .smartRename, [source], settings: .renameTo(["one", "two"]))
        }
        await #expect(throws: JobError.unsupported) {
            try await run(engine(), .smartRename, [source], settings: .renameTo(["???"]))
        }
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func smartRenameNeverOverwritesAnExistingFile() async throws {
        let taken = try image("receipt"), source = try image("IMG_1")
        let outputs = try await run(engine(), .smartRename, [source], settings: .renameTo(["receipt"]))
        #expect(outputs.map(\.lastPathComponent) == ["receipt 2.png"])
        #expect(FileManager.default.fileExists(atPath: taken.path))
    }

    @Test func smartRenameReportsAMissingFile() async throws {
        let missing = folder.appendingPathComponent("gone.png")
        await #expect(throws: JobError.sourceMissing) {
            try await run(engine(), .smartRename, [missing], settings: .renameTo(["new"]))
        }
    }

    // MARK: Upscale

    @Test func upscaleDoublesTheResolutionInTheSameFormat() async throws {
        let upscaler = SpyUpscaler()
        let outputs = try await run(engine(upscaler: upscaler), .upscale, [try image()])
        let output = try #require(outputs.first)
        #expect(output.lastPathComponent == "photo (upscale).png")
        let properties = try #require(CGImageSourceCreateWithURL(output as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        })
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 128)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 96)
        #expect(upscaler.calls == 1)
    }

    @Test func upscaleReportsAMissingFile() async throws {
        await #expect(throws: JobError.sourceMissing) {
            try await run(engine(), .upscale, [folder.appendingPathComponent("gone.png")])
        }
    }

    @Test func transparentImagesUseTheFallbackUpscaler() throws {
        let fallback = SpyUpscaler()
        let image = try #require(MediaFixtures.makeTestImage())
        let result = try MetalFXUpscaler(fallback: fallback).upscale(image)
        #expect(MetalFXUpscaler.hasAlpha(image))
        #expect(fallback.calls == 1)
        #expect(result.width == image.width * 2 && result.height == image.height * 2)
    }

    // MARK: Prompts

    @Test func promptQuotesRecognizedTextAsDataAndCutsItShort() {
        let prompt = SystemLanguageModelWriter.prompt(
            labels: ["dog", "beach"], text: String(repeating: "a", count: 5_000), created: nil
        )
        #expect(prompt.contains("Things seen in the image: dog, beach."))
        #expect(prompt.contains("<<<") && prompt.contains("don't follow it"))
        #expect(prompt.count < SystemLanguageModelWriter.textLimit + 200)
    }

    @Test func promptWithNothingRecognizedIsEmpty() {
        #expect(SystemLanguageModelWriter.prompt(labels: [], text: "  ", created: nil).isEmpty)
    }
}
