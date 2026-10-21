import Foundation
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("iWork automation")
struct IWorkTests {
    @Test("conversions route to the right app, with helper legs where the app cannot read or write directly",
          arguments: [
              ("pages", "docx", IWorkPlan(app: .pages, before: nil, exportKind: "docx", after: nil)),
              ("pages", "md", IWorkPlan(app: .pages, before: nil, exportKind: "docx", after: "md")),
              ("rtf", "pages", IWorkPlan(app: .pages, before: nil, exportKind: "pages", after: nil)),
              ("md", "pages", IWorkPlan(app: .pages, before: IWorkEngine.docx, exportKind: "pages", after: nil)),
              ("pdf", "pages", IWorkPlan(app: .pages, before: IWorkEngine.docx, exportKind: "pages", after: nil)),
              ("ppt", "pptx", IWorkPlan(app: .keynote, before: nil, exportKind: "pptx", after: nil)),
              ("pptx", "png", IWorkPlan(app: .keynote, before: nil, exportKind: "png", after: nil)),
              ("xls", "csv", IWorkPlan(app: .numbers, before: nil, exportKind: "xlsx", after: "csv"))
          ])
    func plans(source: String, target: String, plan: IWorkPlan) {
        #expect(IWorkPlan.make(source: source, target: target) == plan)
    }

    @Test("unknown combinations have no plan")
    func noPlan() {
        #expect(IWorkPlan.make(source: "pptx", target: "pptx") == nil)
        #expect(IWorkPlan.make(source: "png", target: "pages") == nil)
        #expect(IWorkPlan.make(source: "pages", target: "pages") == nil)
    }

    @Test("scripts take paths only from argv and every export kind has a branch", arguments: IWorkApp.allCases)
    func scripts(app: IWorkApp) {
        let script = app.script.joined(separator: "\n")
        #expect(script.contains("POSIX file (item 1 of argv)"))
        #expect(!script.contains("/Users") && !script.contains("\\(" ))
        for kind in app.exportKinds {
            #expect(script.contains("exportKind is \"\(kind)\" then"))
        }
        #expect(script.contains("tell application id \"\(app.rawValue)\""))
    }

    @Test("Automation consent errors are recognized")
    func errors() {
        #expect(IWorkAutomation.error(from: ["execution error: Not authorized to send Apple events to Pages. (-1743)"])
            == .automationDenied)
        #expect(IWorkAutomation.error(from: ["execution error: Can’t get document. (-1728)"]) == .failed)
    }

    @Test("paths need the app installed and any helper engine available")
    func availability() {
        let pages = SubtitleTests.format("pages", family: .document)
        let markdown = FormatDescriptor(id: FormatID("md"), displayName: "MD", extensions: ["md"], family: .document)
        let naming = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        let withHelpers = IWorkEngine(helpers: [DocumentsEngine()], naming: naming) { _ in true }
        let noApps = IWorkEngine(helpers: [DocumentsEngine()], naming: naming) { _ in false }
        let noHelpers = IWorkEngine(helpers: [], naming: naming) { _ in true }
        #expect(withHelpers.canConvert(from: markdown, to: pages))
        #expect(!noApps.canConvert(from: markdown, to: pages))
        #expect(!noHelpers.canConvert(from: markdown, to: pages))
        #expect(noHelpers.canConvert(from: IWorkEngine.docx, to: pages))
    }

    @Test("multiple exported files go into a numbered folder; one file goes to the destination")
    func placement() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try folder.file("deck.pptx")
        let png = FormatDescriptor(id: FormatID("png"), displayName: "PNG", extensions: ["png"], family: .image)
        let request = ConversionRequest(
            source: source, destination: folder.url.appendingPathComponent("deck.png"),
            sourceFormat: FormatDescriptor(id: FormatID("pptx"), displayName: "PPTX", extensions: ["pptx"],
                                           family: .presentation),
            targetFormat: png
        )
        let sut = OutputPlacement(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        let files = try ["s.010.png", "s.002.png", "s.001.png"].map { try folder.file($0) }
        let placed = try sut.place(files, for: request)
        #expect(placed.map(\.lastPathComponent) == ["deck (PNG)"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: placed[0].path).sorted()
            == ["deck 1.png", "deck 2.png", "deck 3.png"])
        let single = try sut.place([try folder.file("one.png")], for: request)
        #expect(single == [request.destination])
        #expect(throws: JobError.failed) { try sut.place([], for: request) }
    }
    @Test("failed multi-slide placement removes its owned partial output folder")
    func placementRollback() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try folder.file("deck.pptx")
        let request = ConversionRequest(source: source, destination: folder.url.appendingPathComponent("deck.png"),
            sourceFormat: FormatDescriptor(id: FormatID("pptx"), displayName: "PPTX", extensions: ["pptx"],
                                           family: .presentation), targetFormat: CatalogFixtures.png)
        let placement = OutputPlacement(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        let first = try folder.file("a.png")
        let missing = folder.url.appendingPathComponent("b.png")
        #expect(throws: JobError.destinationUnavailable) { try placement.place([first, missing], for: request) }
        let entries = try FileManager.default.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: nil)
        #expect(!entries.contains { $0.lastPathComponent.hasPrefix("deck (PNG)") })
        #expect(FileManager.default.fileExists(atPath: source.path))
    }
}
