import Foundation
import Testing
import TransfloDomain
@testable import TransfloMobile

@Suite("Mobile home")
struct MobileHomeViewModelTests {
    private let picked = [URL(fileURLWithPath: "/picked/photo.heic")]
    private let copies = [URL(fileURLWithPath: "/Documents/2026-10-20 at 10.00.00/photo.heic")]

    @Test("picked files are imported and the wheel opens for the copies")
    func opensWheel() async {
        // Given an importer that copies the file
        let importer = StubFileImporter(copies: copies)
        let wheel = SpyWheelOpener()
        let sut = MobileHomeViewModel(importer: importer, wheel: wheel)
        // When files arrive
        await sut.receive(picked)
        // Then the copies (not the lent originals) reach the wheel
        #expect(importer.imported == [picked])
        #expect(wheel.opened == [copies])
        #expect(sut.state == .init(isImporting: false, message: nil))
    }

    @Test("files no wheel can handle say so")
    func noOptions() async {
        let sut = MobileHomeViewModel(importer: StubFileImporter(copies: copies),
                                      wheel: SpyWheelOpener(hasOptions: false))
        await sut.receive(picked)
        #expect(sut.state.message == .mobileNoOptions)
    }

    @Test("archives are rejected before importing, including mixed batches",
          arguments: ["zip", "rar", "tar", "gz"])
    func archiveRejected(ext: String) async {
        let importer = StubFileImporter(copies: copies)
        let wheel = SpyWheelOpener()
        let sut = MobileHomeViewModel(importer: importer, wheel: wheel,
                                      inputs: MobileInputCatalog(catalog: MobileConversionFactory().catalog))
        let archive = URL(fileURLWithPath: "/picked/bundle.\(ext)")
        await sut.receive([archive])
        #expect(sut.state.message == .mobileNoOptions)
        await sut.receive(picked + [archive])
        #expect(sut.state.message == .mobileNoOptions)
        #expect(importer.imported.isEmpty && wheel.opened.isEmpty && !sut.state.isImporting)
    }

    @Test("a failed import shows an error and opens nothing")
    func importFails() async {
        let wheel = SpyWheelOpener()
        let sut = MobileHomeViewModel(importer: StubFileImporter(error: .destinationUnavailable), wheel: wheel)
        await sut.receive(picked)
        #expect(sut.state.message == .mobileImportFailed)
        #expect(wheel.opened.isEmpty && !sut.state.isImporting)
    }

    @Test("nothing picked does nothing; a picker failure shows an error that can be dismissed")
    func emptyAndFailure() async {
        let importer = StubFileImporter(copies: copies)
        let sut = MobileHomeViewModel(importer: importer, wheel: SpyWheelOpener())
        await sut.receive([])
        #expect(importer.imported.isEmpty && sut.state.message == nil)
        sut.receiveFailed()
        #expect(sut.state.message == .mobileImportFailed)
        sut.dismissMessage()
        #expect(sut.state.message == nil)
    }

    @Test("cancelling Files does not report a failed import, but a real picker error does")
    func pickerErrors() {
        let sut = MobileHomeViewModel(importer: StubFileImporter(copies: copies), wheel: SpyWheelOpener())
        sut.pickerFailed(CocoaError(.userCancelled))
        #expect(sut.state.message == nil)
        sut.pickerFailed(CocoaError(.fileReadNoPermission))
        #expect(sut.state.message == .mobileImportFailed)
    }
}
