import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Editor-driven tools", .enabled(if: MediaFixtures.hasFFmpeg))
struct EditToolTests {
    private let catalog = MatrixConversionTests.catalog
    private var engines: [any ToolEngine] {
        [
            ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: MediaToolTests.naming, copier: SpyCopier()),
            MediaToolEngine(
                ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming
            ),
            PDFToolEngine(naming: MediaToolTests.naming)
        ]
    }
    private let previews = MediaToolPreviewProvider(ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe)

    private func run(_ tool: ToolKind, _ url: URL, _ settings: ToolSettings) async throws -> [URL] {
        let item = ToolItem(url: url, format: catalog.format(forFileExtension: url.pathExtension))
        let engine = try #require(engines.first { $0.canRun(tool, on: [item.format]) })
        return try await engine.run(ToolRequest(tool: tool, settings: settings, items: [item])) { _ in }
    }

    private func size(_ url: URL) throws -> (Int, Int) {
        let properties = try #require(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        })
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        return (width, properties[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    private func probe(_ url: URL) async throws -> MediaInfo {
        try await FFprobe.info(binary: try #require(MediaFixtures.ffprobe), file: url)
    }

    @Test("images resize, crop and adjust")
    func images() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("png", into: folder.url)
        #expect(try size(try await run(.resize, source, .resize(width: 32, height: 24))[0]) == (32, 24))
        let half = NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        #expect(try size(try await run(.crop, source, .crop(half))[0]) == (32, 24))
        let lift = ImageAdjustments(exposure: 1, contrast: 1, saturation: 1)
        let brighter = try await run(.adjust, source, .adjust(lift))
        #expect(try size(brighter[0]) == (64, 48))
    }

    @Test("videos resize and crop to even sizes")
    func videoGeometry() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let resized = try await probe(try await run(.resize, source, .resize(width: 65, height: 49))[0])
        #expect(resized.width == 64 && resized.height == 48)
        let center = NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let cropped = try await probe(try await run(.crop, source, .crop(center))[0])
        #expect(cropped.width == 64 && cropped.height == 48)
    }

    @Test("trim keeps the chosen range", arguments: ["mp4", "mp3"])
    func trim(format: String) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy(format, into: folder.url)
        let info = try await probe(try await run(.trim, source, .trim(start: 0.2, end: 0.7))[0])
        #expect(abs((info.duration ?? 0) - 0.5) < 0.15)
    }

    @Test("change speed scales the duration and keeps sound", arguments: [(2.0, 0.5), (0.5, 2.0)])
    func speed(factor: Double, duration: Double) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let info = try await probe(try await run(.changeSpeed, source, .changeSpeed(factor))[0])
        #expect(abs((info.duration ?? 0) - duration) < 0.2)
        #expect(info.hasAudio)
    }

    @Test("split writes one numbered file per segment")
    func splitMedia() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp3", into: folder.url)
        let parts = try await run(.split, source, .split(points: [0.5]))
        #expect(parts.map(\.lastPathComponent) == ["source (split).mp3", "source (split) 2.mp3"])
        for part in parts {
            #expect(abs((try await probe(part).duration ?? 0) - 0.5) < 0.15)
        }
        await #expect(throws: JobError.incompatibleSelection) { _ = try await run(.split, source, .split(points: [5])) }
    }

    @Test("snapshot saves the frame as PNG")
    func snapshot() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let frame = try await run(.snapshot, source, .snapshot(at: 0.5))
        #expect(frame.map(\.lastPathComponent) == ["source (snapshot).png"])
        #expect(try size(frame[0]) == (128, 96))
    }

    @Test("PDFs split every N pages; too-short PDFs report nothing to split")
    func splitPDF() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("doc.pdf")
        try DocumentFixtures.makePDF(pages: 3, to: source)
        let pages = try #require(PDFDocument(url: source)?.pageCount)
        let parts = try await run(.split, source, .splitPages(every: 1))
        #expect(parts.count == pages)
        await #expect(throws: JobError.incompatibleSelection) {
            _ = try await run(.split, source, .splitPages(every: 99))
        }
    }

    @Test("the tempo chain splits large speed changes into atempo stages")
    func tempo() {
        #expect(MediaEditArguments.tempoChain(4) == "atempo=2,atempo=2.000")
        #expect(MediaEditArguments.tempoChain(0.25) == "atempo=0.5,atempo=0.500")
        #expect(MediaEditArguments.tempoChain(1.5) == "atempo=1.500")
        #expect(MediaEditArguments.changeSpeed("/a.mp3", format: "mp3", factor: 9, hasAudio: true) == nil)
        #expect(MediaEditArguments.trim("/a.mp3", format: "mp3", start: 2, end: 1) == nil)
    }

    @Test("previews report size, length, pages and a thumbnail")
    func previewFacts() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let image = try await FixtureCache.shared.copy("png", into: folder.url)
        let video = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let audio = try await FixtureCache.shared.copy("mp3", into: folder.url)
        let pdf = folder.url.appendingPathComponent("p.pdf")
        try DocumentFixtures.makePDF(pages: 2, to: pdf)
        let imagePreview = await previews.preview(of: image, format: catalog.format(FormatID("png")))
        #expect(imagePreview.width == 64 && imagePreview.thumbnail != nil)
        let videoPreview = await previews.preview(of: video, format: catalog.format(FormatID("mp4")))
        #expect(videoPreview.width == 128 && (videoPreview.duration ?? 0) > 0.5 && videoPreview.thumbnail != nil)
        let audioPreview = await previews.preview(of: audio, format: catalog.format(FormatID("mp3")))
        #expect(audioPreview.duration != nil && audioPreview.thumbnail == nil)
        let pdfPreview = await previews.preview(of: pdf, format: catalog.format(FormatID("pdf")))
        #expect((pdfPreview.pageCount ?? 0) >= 2 && pdfPreview.thumbnail != nil)
        let thumbnail = try #require(imagePreview.thumbnail)
        let gray = ImageAdjustments(exposure: 1, contrast: 1, saturation: 0)
        #expect(await previews.adjusted(thumbnail, with: gray) != nil)
        #expect(await previews.preview(of: image, format: nil) == .empty)
    }
}
