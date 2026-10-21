import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

/// Converts a generated fixture through every catalog path with the real engines.
@Suite("Conversion matrix", .serialized,
       .enabled(if: MediaFixtures.hasFFmpeg, "needs Vendor/ffmpeg (scripts/build-ffmpeg.sh)"))
struct MatrixConversionTests {
    struct Case: CustomTestStringConvertible, Sendable {
        let source: String
        let target: String
        var testDescription: String { "\(source) → \(target)" }
    }

    static let catalog = (try? BundledCatalogLoader().load()) ?? ConversionCatalog(formats: [], paths: [])
    /// iWork paths drive Pages/Keynote/Numbers and trigger Automation consent prompts, so they run
    /// only when `TRANSFLO_IWORK_TESTS=1`. PPT and XLS inputs are skipped: nothing on macOS writes them.
    static let runsIWork = ProcessInfo.processInfo.environment["TRANSFLO_IWORK_TESTS"] == "1"
    static let cases = catalog.paths
        .filter { runsIWork || !$0.engines.contains(EngineIDs.iWork) }
        .filter { !["ppt", "xls"].contains($0.source.rawValue) }
        .map { Case(source: $0.source.rawValue, target: $0.target.rawValue) }

    static func makeRunner() -> ConversionJobRunner {
        ConversionJobRunner(
            catalog: catalog,
            engines: allEngines,
            naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()),
            remover: FileManagerFileRemover()
        )
    }

    static var allEngines: [any ConversionEngine] {
        let naming = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        let imageIO = ImageIOEngine()
        let ffmpeg = FFmpegEngine(binary: MediaFixtures.ffmpeg)
        let helpers: [any ConversionEngine] = [
            imageIO, SVGEngine(rasterEngines: [imageIO, ffmpeg]), AVFoundationEngine(), ffmpeg,
            SubtitleEngine(), ArchiveEngine(), DocumentsEngine(), PDFKitEngine(naming: naming), SpreadsheetEngine()
        ]
        return helpers + [IWorkEngine(helpers: helpers, naming: naming)]
    }

    @Test("every path produces a readable file of the target format", arguments: cases)
    func convert(_ testCase: Case) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        // Given
        let source = try await FixtureCache.shared.copy(testCase.source, into: folder.url)
        let target = try #require(Self.catalog.format(FormatID(testCase.target)))
        // When
        let outputs = try await Self.makeRunner().run(WheelOption(.format(target)), on: [source]) { _ in }
        // Then
        let output = try #require(outputs.first)
        var isFolder: ObjCBool = false
        FileManager.default.fileExists(atPath: output.path, isDirectory: &isFolder)
        let files = isFolder.boolValue
            ? try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
                .sorted { $0.path < $1.path }
            : [output]
        #expect(!files.isEmpty)
        for file in files {
            #expect(file.lastPathComponent.hasSuffix("." + target.outputExtension))
            let size = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int ?? 0
            #expect(size > 0)
            try await verify(file, as: testCase.target, source: testCase.source)
        }
        #expect(FileManager.default.fileExists(atPath: source.path), "the original must be untouched")
    }

    private func readText(_ url: URL, as target: String) throws -> String {
        switch target {
        case "docx": try DocumentReader.read(url, format: "docx").text.string
        case "epub": try DocumentReader.read(url, format: "epub").text.string
        default: try String(contentsOf: url, encoding: .utf8)
        }
    }

    private func verify(_ output: URL, as target: String, source: String) async throws {
        if target == "pages" {
            let names = await DocumentFixtures.entries(of: output) ?? []
            #expect(names.contains { $0.hasPrefix("Index/") && $0.hasSuffix(".iwa") })
        } else if ["srt", "vtt", "txt", "md", "html", "docx", "epub"].contains(target) {
            let text = try readText(output, as: target)
            #expect(text.contains("Hello") || text.contains("hi from"), "unexpected text: \(text.prefix(80))")
        } else if ["xlsx", "ods", "csv", "tsv"].contains(target) {
            let cells = try SpreadsheetFiles.read(output, format: target).sheets.flatMap(\.rows).flatMap { $0 }
            #expect(cells.contains { $0.text.contains("Hello") }, "no greeting cell found")
        } else if target == "pptx" {
            let required = ["ppt/presentation.xml", "ppt/slides/slide1.xml"]
            #expect(try OOXMLTestSupport.partsParse(output, required: required))
        } else if ["zip", "tar", "gz"].contains(target) {
            let entries = await DocumentFixtures.entries(of: output) ?? []
            #expect(!entries.isEmpty, "archive should list entries")
        } else if target == "pdf" {
            let document = try #require(PDFDocument(url: output))
            #expect(document.pageCount >= 1)
            if source == "pptx" {
                // The generated deck contains rasterized PDF pages, not editable text.
                #expect(document.pageCount >= 2)
                let page = try #require(document.page(at: 0))
                #expect(page.thumbnail(of: CGSize(width: 160, height: 160), for: .mediaBox).tiffRepresentation != nil)
            } else if source != "svg", document.string?.isEmpty == false {
                #expect(document.string?.contains("Hello") == true)
            }
        } else if let type = MediaFixtures.imageIOTypes[target], target != "gif" {
            let source = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
            #expect(CGImageSourceGetType(source) as String? == type.identifier)
        } else {
            let container = await MediaFixtures.probeContainer(output)
            let token = try #require(MediaFixtures.containerTokens[target])
            #expect(container?.contains(token) == true, "ffprobe saw \(container ?? "nothing")")
        }
    }
}
