import Testing
@testable import Transflo
import TransfloDomain

@Suite("Settings conversion catalog")
struct SettingsCatalogTests {
    private func model() -> SettingsCatalogViewModel {
        let formats = [
            FormatDescriptor(id: FormatID("jpg"), displayName: "JPG", extensions: ["jpg", "jpeg"], family: .image),
            FormatDescriptor(id: FormatID("png"), displayName: "PNG", extensions: ["png"], family: .image),
            FormatDescriptor(id: FormatID("pdf"), displayName: "PDF", extensions: ["pdf"], family: .document)
        ]
        return SettingsCatalogViewModel(catalog: ConversionCatalog(formats: formats, paths: [
            ConversionPath(source: FormatID("jpg"), target: FormatID("png"), engines: [EngineID("imageio")]),
            ConversionPath(source: FormatID("jpg"), target: FormatID("pdf"), engines: [EngineID("imageio")])
        ]))
    }

    @Test("format search includes alternate extensions and does not change shared defaults selection")
    func search() {
        let sut = model()
        sut.search = " JPEG "
        #expect(sut.groups.flatMap(\.formats).map(\.id) == [FormatID("jpg")])
        #expect(sut.selectedFormat == nil)
        sut.search = "missing"
        #expect(sut.groups.isEmpty)
        sut.search = "  "
        #expect(sut.groups.flatMap(\.formats).count == 3)
    }

    @Test("matrix and format detail reflect catalog paths including cross-family outputs")
    func actualRoutes() {
        let sut = model()
        sut.selectedFormat = FormatID("jpg")
        #expect(sut.targets.map(\.id) == [FormatID("png"), FormatID("pdf")])
        #expect(sut.matrixTargets.map(\.id) == sut.targets.map(\.id))
        #expect(sut.supports(FormatID("jpg"), FormatID("pdf")))
        #expect(!sut.supports(FormatID("png"), FormatID("jpg")))
        #expect(!sut.supports(FormatID("jpg"), FormatID("jpg")))
        sut.family = .document
        #expect(sut.matrixSources.map(\.id) == [FormatID("pdf")])
        #expect(sut.matrixTargets.isEmpty)
        sut.selectedFormat = FormatID("png")
        #expect(sut.targets.isEmpty)
    }
}
