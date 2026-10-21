import Foundation
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Editor support: page thumbnails and current metadata", .enabled(if: MediaFixtures.hasFFmpeg))
struct EditorSupportTests {
    private let catalog = MatrixConversionTests.catalog
    private let previews = MediaToolPreviewProvider(ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe)
    private let reader = FileMetadataReader(ffprobe: MediaFixtures.ffprobe)
    private let values: [MetadataField: String] = [.title: "Trip", .author: "Ali", .comment: "Day one"]

    private func edited(_ format: String, in folder: URL) async throws -> URL {
        let source = try await FixtureCache.shared.copy(format, into: folder)
        let item = ToolItem(url: source, format: catalog.format(forFileExtension: format))
        let engines: [any ToolEngine] = [
            ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: MediaToolTests.naming, copier: SpyCopier()),
            MediaToolEngine(
                ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe, naming: MediaToolTests.naming
            ),
            PDFToolEngine(naming: MediaToolTests.naming)
        ]
        let engine = try #require(engines.first { $0.canRun(.editMetadata, on: [item.format]) })
        let request = ToolRequest(tool: .editMetadata, settings: .metadata(values), items: [item])
        return try #require(try await engine.run(request) { _ in }.first)
    }

    @Test("PDF page thumbnails come one per page, in order; other files get none")
    func pageThumbnails() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let pdf = folder.url.appendingPathComponent("p.pdf")
        try DocumentFixtures.makePDF(pages: 3, to: pdf)
        let thumbnails = await previews.pageThumbnails(of: pdf)
        #expect(thumbnails.count == 3)
        #expect(thumbnails.allSatisfy { !$0.isEmpty })
        let image = try await FixtureCache.shared.copy("png", into: folder.url)
        #expect(await previews.pageThumbnails(of: image).isEmpty)
    }

    @Test("metadata written by Edit metadata reads back", arguments: ["jpg", "png", "heic", "mp3", "mp4", "pdf"])
    func readsBack(format: String) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let output = try await edited(format, in: folder.url)
        #expect(await reader.metadata(of: output, format: catalog.format(forFileExtension: format)) == values)
    }

    @Test("files without metadata, unknown formats and missing files read as empty")
    func emptyCases() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let png = try await FixtureCache.shared.copy("png", into: folder.url)
        #expect(await reader.metadata(of: png, format: catalog.format(FormatID("png"))).isEmpty)
        #expect(await reader.metadata(of: png, format: nil).isEmpty)
        let missing = folder.url.appendingPathComponent("gone.mp3")
        #expect(await reader.metadata(of: missing, format: catalog.format(FormatID("mp3"))).isEmpty)
        let missingPDF = folder.url.appendingPathComponent("gone.pdf")
        #expect(await reader.metadata(of: missingPDF, format: catalog.format(FormatID("pdf"))).isEmpty)
    }
}
