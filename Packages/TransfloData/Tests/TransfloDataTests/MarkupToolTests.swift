import AppKit
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Markup, page and file tools", .enabled(if: MediaFixtures.hasFFmpeg))
struct MarkupToolTests {
    private let catalog = MatrixConversionTests.catalog
    private var engines: [any ToolEngine] {
        [
            ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: MediaToolTests.naming, copier: SpyCopier()),
            MediaToolEngine(
                ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming
            ),
            PDFToolEngine(naming: MediaToolTests.naming),
            FileToolEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        ]
    }

    private func run(_ tool: ToolKind, _ urls: [URL], _ settings: ToolSettings) async throws -> [URL] {
        let items = urls.map { ToolItem(url: $0, format: catalog.format(forFileExtension: $0.pathExtension)) }
        let engine = try #require(engines.first { $0.canRun(tool, on: items.map(\.format)) })
        return try await engine.run(ToolRequest(tool: tool, settings: settings, items: items)) { _ in }
    }

    private func pixel(_ url: URL, x: Int, y: Int) throws -> [UInt8] {
        let image = try #require(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
            CGImageSourceCreateImageAtIndex($0, 0, nil)
        })
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data?.assumingMemoryBound(to: UInt8.self))
        let offset = (y * image.width + x) * 4
        return Array(UnsafeBufferPointer(start: bytes + offset, count: 4))
    }

    @Test("image redaction paints black; background fills transparency; annotation draws")
    func imageMarkup() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try await FixtureCache.shared.copy("png", into: folder.url)
        let redacted = try await run(.redact, [source], .redact([NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 1)]))
        #expect(try pixel(redacted[0], x: 60, y: 10).prefix(3) == [0, 0, 0])
        let filled = try await run(.addBackground, [source], .addBackground(color: "#FF0000"))
        #expect(try pixel(filled[0], x: 2, y: 2) == [255, 0, 0, 255])
        let box = Annotation(kind: .rectangle, points: [UnitPoint(x: 0, y: 0), UnitPoint(x: 0.4, y: 0.4)],
                             color: "#00FF00", weight: 0.08)
        let marked = try await run(.annotate, [source], .annotate([box]))
        #expect(try pixel(marked[0], x: 1, y: 1)[1] > 200)
    }

    @Test("collage lays images in a grid; image metadata is written")
    func collageAndMetadata() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = try await FixtureCache.shared.copy("png", into: folder.url)
        let second = folder.url.appendingPathComponent("second.png")
        try FileManager.default.copyItem(at: first, to: second)
        let grid = try await run(.collage, [first, second], .collage(columns: 2, spacing: 4, background: "#FFFFFF"))
        let properties = try #require(CGImageSourceCreateWithURL(grid[0] as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        })
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 64 * 2 + 12)
        let jpg = try await FixtureCache.shared.copy("jpg", into: folder.url)
        let tagged = try await run(.editMetadata, [jpg], .metadata([.title: "Sunset"]))
        let iptc = try #require(CGImageSourceCreateWithURL(tagged[0] as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        }?[kCGImagePropertyIPTCDictionary] as? [CFString: Any])
        #expect(iptc[kCGImagePropertyIPTCObjectName] as? String == "Sunset")
    }

    @Test("PDF pages reorder and extract; redaction removes the covered text; annotations and metadata stick")
    func pdfTools() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("doc.pdf")
        try DocumentFixtures.makePDF(pages: 3, to: source)
        let count = try #require(PDFDocument(url: source)?.pageCount)
        let reversed = try await run(.reorganizePages, [source], .pages(Array((0..<count).reversed())))
        #expect(PDFDocument(url: reversed[0])?.pageCount == count)
        let one = try await run(.extractPages, [source], .pages([0]))
        #expect(PDFDocument(url: one[0])?.pageCount == 1)
        await #expect(throws: JobError.incompatibleSelection) {
            _ = try await run(.extractPages, [source], .pages([99]))
        }
        let redacted = try await run(.redact, [source], .redact([.full]))
        #expect(PDFDocument(url: redacted[0])?.page(at: 0)?.string?.contains("Hello") != true)
        let arrow = Annotation(kind: .arrow, points: [UnitPoint(x: 0.1, y: 0.1), UnitPoint(x: 0.5, y: 0.5)],
                               color: "#136F63", weight: 0.01)
        let note = Annotation(kind: .text("Check"), points: [UnitPoint(x: 0.2, y: 0.8)], color: "#000000", weight: 0.01)
        let annotated = try await run(.annotate, [source], .annotate([arrow, note]))
        #expect(PDFDocument(url: annotated[0])?.page(at: 0)?.annotations.count == 2)
        let titled = try await run(.editMetadata, [source], .metadata([.title: "Report", .author: "Transflo"]))
        let attributes = PDFDocument(url: titled[0])?.documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.titleAttribute] as? String == "Report")
    }

    @Test("bleep keeps length and sound; media tags are written")
    func mediaTools() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let probe = try #require(MediaFixtures.ffprobe)
        let clip = try await FixtureCache.shared.copy("mp4", into: folder.url)
        let bleeped = try await run(.bleep, [clip], .bleep([TimeSpan(start: 0.2, end: 0.5)]))
        let info = try await FFprobe.info(binary: probe, file: bleeped[0])
        #expect(info.hasVideo && info.hasAudio && abs((info.duration ?? 0) - 1) < 0.2)
        let song = try await FixtureCache.shared.copy("mp3", into: folder.url)
        let tagged = try await run(.editMetadata, [song], .metadata([.title: "Hymn", .author: "Band"]))
        let tags = try await FFprobe.info(binary: probe, file: tagged[0]).tags
        #expect(tags["title"] == "Hymn" && tags["artist"] == "Band")
    }

    @Test("rename moves files to the pattern and avoids collisions")
    func rename() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = try folder.file("a.txt")
        let second = try folder.file("b.txt")
        _ = try folder.file("Trip 2.txt")
        let renamed = try await run(.rename, [first, second], .rename(pattern: "Trip {n}", start: 1))
        #expect(renamed.map(\.lastPathComponent) == ["Trip 1.txt", "Trip 2 2.txt"])
        #expect(!FileManager.default.fileExists(atPath: first.path))
    }

    @Test("on iPhone and iPad, rename writes renamed copies and never touches or overwrites a file")
    func renameKeepsOriginals() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = try folder.file("a.txt")
        let taken = try folder.file("Trip 1.txt")
        let before = try Data(contentsOf: taken)
        let engine = FileToolEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()),
                                    keepsOriginals: true)
        let request = ToolRequest(tool: .rename, settings: .rename(pattern: "Trip {n}", start: 1),
                                  items: [ToolItem(url: first, format: nil)])
        let renamed = try await engine.run(request) { _ in }
        #expect(renamed.map(\.lastPathComponent) == ["Trip 1 2.txt"])
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(try Data(contentsOf: taken) == before)
        // A missing source is reported, not silently skipped.
        try FileManager.default.removeItem(at: first)
        await #expect(throws: JobError.sourceMissing) { try await engine.run(request) { _ in } }
    }
}
