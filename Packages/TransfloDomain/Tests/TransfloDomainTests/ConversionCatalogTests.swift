import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("ConversionCatalog")
struct ConversionCatalogTests {
    private let catalog = CatalogFixtures.catalog

    @Test("formats resolve by id and by any extension, ignoring case")
    func lookups() {
        #expect(catalog.format(FormatID("PNG")) == CatalogFixtures.png)
        #expect(catalog.format(forFileExtension: "JPEG") == CatalogFixtures.jpg)
        #expect(catalog.format(forFileExtension: "jpg") == CatalogFixtures.jpg)
        #expect(catalog.format(forFileExtension: "xyz") == nil)
        #expect(catalog.format(forFileExtension: "") == nil)
    }

    @Test("targets keep catalog order")
    func targets() {
        #expect(catalog.targets(from: CatalogFixtures.png.id) == [CatalogFixtures.jpg, CatalogFixtures.webp])
        #expect(catalog.targets(from: CatalogFixtures.wav.id).isEmpty)
    }

    @Test("paths resolve by route")
    func paths() {
        let path = catalog.path(from: CatalogFixtures.png.id, to: CatalogFixtures.jpg.id)
        #expect(path?.engines == [CatalogFixtures.imageIO, CatalogFixtures.ffmpeg])
        #expect(catalog.path(from: CatalogFixtures.wav.id, to: CatalogFixtures.mp3.id) == nil)
    }

    @Test("restricting to engines keeps only paths a capable engine can run")
    func restricted() {
        let imageIOOnly = catalog.restricted(to: [FakeConversionEngine(id: CatalogFixtures.imageIO)])
        #expect(imageIOOnly.targets(from: CatalogFixtures.png.id) == [CatalogFixtures.jpg])
        #expect(imageIOOnly.formats == catalog.formats)
        let incapable = catalog.restricted(to: [FakeConversionEngine(id: CatalogFixtures.ffmpeg, isCapable: false)])
        #expect(incapable.paths.isEmpty)
        #expect(catalog.restricted(to: []).paths.isEmpty)
    }

    @Test("the first output extension is used for outputs")
    func outputExtension() {
        #expect(CatalogFixtures.jpg.outputExtension == "jpg")
        let bare = FormatDescriptor(id: FormatID("raw"), displayName: "RAW", extensions: [], family: .image)
        #expect(bare.outputExtension == "raw")
    }
}

@Suite("CatalogWheelOptionsProvider")
struct CatalogWheelOptionsProviderTests {
    private let fallback = StubWheelOptionsProvider([.actions: [WheelOption(.action(.copy))]])

    private func convert(_ names: [String]) -> [WheelOption] {
        CatalogWheelOptionsProvider(catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog, fallback: fallback)
            .options(for: .convert, items: names.map { URL(fileURLWithPath: "/tmp/\($0)") })
    }

    @Test("a single file offers every target from its format")
    func singleFile() {
        let expected = [CatalogFixtures.jpg, CatalogFixtures.webp].map { WheelOption(.format($0)) }
        #expect(convert(["a.png"]) == expected)
    }

    @Test("mixed files offer only shared targets that none of them already are")
    func intersection() {
        #expect(convert(["a.png", "b.JPEG"]) == [WheelOption(.format(CatalogFixtures.webp))])
    }

    @Test("files with no shared target, unknown files or no files show nothing")
    func empty() {
        #expect(convert(["a.png", "b.mp3"]).isEmpty)
        #expect(convert(["a.png", "notes.xyz"]).isEmpty)
        #expect(convert(["folder"]).isEmpty)
        #expect(convert([]).isEmpty)
    }

    @Test("tools are those that accept every dragged file")
    func toolOptions() {
        let sut = CatalogWheelOptionsProvider(
            catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog, fallback: fallback
        )
        func tools(_ names: [String]) -> [ToolKind] {
            sut.options(for: .tools, items: names.map { URL(fileURLWithPath: "/tmp/\($0)") }).compactMap {
                if case .tool(let kind) = $0.kind { kind } else { nil }
            }
        }
        #expect(tools(["a.png"]) == [.compress, .rotate, .rename])
        #expect(tools(["a.png", "b.mp3"]) == [.compress, .rename])
        #expect(tools(["a.mp3", "b.wav"]) == [.compress, .merge, .rename])
        #expect(tools(["notes.xyz"]) == [.rename])
        #expect(tools([]).isEmpty)
    }

    @Test("actions come from the fallback")
    func fallbackWheels() {
        let sut = CatalogWheelOptionsProvider(
            catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog, fallback: fallback
        )
        let items = [URL(fileURLWithPath: "/tmp/a.png")]
        #expect(sut.options(for: .actions, items: items) == [WheelOption(.action(.copy))])
    }
}
