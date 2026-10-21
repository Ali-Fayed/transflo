import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Bundled catalog")
struct BundledCatalogTests {
    private let catalog: ConversionCatalog

    init() throws {
        catalog = try BundledCatalogLoader().load()
    }

    @Test("the media catalog has every published path (189)")
    func mediaPathCount() {
        let media: Set<FormatFamily> = [.image, .audio, .video]
        let count = catalog.paths.filter { catalog.format($0.source).map { media.contains($0.family) } == true }.count
        #expect(count == 189)
    }

    @Test("the full catalog matches the published list so far")
    func totalPathCount() {
        #expect(catalog.paths.count == 290)
    }

    @Test("every published media format is present", arguments: [
        "jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "svg", "gif", "pdf",
        "mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma",
        "mp4", "mov", "mkv", "webm", "avi", "wmv"
    ])
    func formatPresent(id: String) {
        #expect(catalog.format(FormatID(id)) != nil)
    }

    @Test("no format converts to itself and every path names an engine")
    func pathsAreSane() {
        #expect(catalog.paths.allSatisfy { $0.source != $0.target && !$0.engines.isEmpty })
    }

    @Test("SVG is input-only; PDF converts onward to documents and images")
    func directionality() {
        #expect(catalog.targets(from: FormatID("pdf")).contains { $0.id == FormatID("docx") })
        #expect(!catalog.paths.contains { $0.target == FormatID("svg") })
        #expect(catalog.targets(from: FormatID("svg")).count == 8)
    }

    @Test("video exports to MP3 and GIF; images export to PDF")
    func publishedExtras() {
        #expect(catalog.path(from: FormatID("mkv"), to: FormatID("mp3")) != nil)
        #expect(catalog.path(from: FormatID("mov"), to: FormatID("gif")) != nil)
        #expect(catalog.path(from: FormatID("heic"), to: FormatID("pdf")) != nil)
    }
}

@Suite("CatalogMapper validation")
struct CatalogMapperTests {
    private func load(_ json: String) throws(CatalogError) -> ConversionCatalog {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-\(UUID().uuidString).json")
        try? Data(json.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        return try BundledCatalogLoader(url: file).load()
    }

    private static func format(_ id: String, extensions: [String]? = nil, family: String = "image") -> String {
        let list = (extensions ?? [id]).map { "\"\($0)\"" }.joined(separator: ",")
        return #"{"id":"\#(id)","name":"\#(id.uppercased())","extensions":[\#(list)],"family":"\#(family)"}"#
    }

    private static func rule(_ from: [String], _ to: [String], engines: [String] = ["imageio"]) -> String {
        func list(_ values: [String]) -> String { values.map { "\"\($0)\"" }.joined(separator: ",") }
        return #"{"from":[\#(list(from))],"to":[\#(list(to))],"engines":[\#(list(engines))]}"#
    }

    private static func catalog(version: Int = 1, formats: [String], rules: [String] = []) -> String {
        let formatList = formats.joined(separator: ",")
        let ruleList = rules.joined(separator: ",")
        return #"{"version":\#(version),"formats":[\#(formatList)],"conversions":[\#(ruleList)]}"#
    }

    @Test("a valid rule expands to every pair except self")
    func expands() throws {
        let formats = [Self.format("png"), Self.format("jpg")]
        let json = Self.catalog(formats: formats, rules: [Self.rule(["png", "jpg"], ["png", "jpg"])])
        #expect(try load(json).paths.count == 2)
    }

    @Test("invalid catalogs are rejected with a reason", arguments: [
        catalog(version: 2, formats: []),
        catalog(formats: [format("x", family: "smell")]),
        catalog(formats: [format("x", extensions: [])]),
        catalog(formats: [format("a", extensions: ["x"]), format("b", extensions: ["X"])]),
        catalog(formats: [format("a")], rules: [rule(["a"], ["zzz"])]),
        catalog(formats: [format("a")], rules: [rule(["a"], ["a"], engines: [])])
    ])
    func rejects(json: String) {
        #expect {
            try load(json)
        } throws: { error in
            if case .invalid = error as? CatalogError { return true }
            return false
        }
    }

    @Test("duplicate conversions are rejected")
    func duplicates() {
        let rule = Self.rule(["png"], ["jpg"])
        let json = Self.catalog(formats: [Self.format("png"), Self.format("jpg")], rules: [rule, rule])
        #expect(throws: CatalogError.invalid(reason: "duplicate conversion png→jpg")) { try load(json) }
    }

    @Test("missing or malformed files are reported")
    func unreadable() {
        #expect(throws: CatalogError.unreadable) { try BundledCatalogLoader(url: nil).load() }
        #expect(throws: CatalogError.invalid(reason: "malformed JSON")) { try load("{ nope") }
    }
}
