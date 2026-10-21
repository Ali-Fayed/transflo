import Foundation
import Testing
import TransfloDomain
@testable import TransfloMobile
import UniformTypeIdentifiers

@Suite("Mobile input and result flow")
struct MobileSaveFlowTests {
    private let photo = URL(fileURLWithPath: "/Documents/photo.png")
    private let pdf = URL(fileURLWithPath: "/Documents/document.pdf")

    @Test("only runnable source categories appear, never archives; Home shows six")
    func supportedInputs() {
        let sut = MobileInputCatalog(catalog: MobileConversionFactory().catalog)
        let kinds = sut.options.map(\.kind)
        #expect(kinds.contains(.image) && kinds.contains(.pdf))
        #expect(kinds.contains(.audio) && kinds.contains(.video) && kinds.contains(.subtitle))
        #expect(kinds.contains(.text) && kinds.contains(.document))
        #expect(sut.accepts([photo, pdf, URL(fileURLWithPath: "/Documents/notes.txt")]))
        #expect(!sut.accepts([URL(fileURLWithPath: "/Documents/bundle.zip")]))
        let conversion = MobileConversionFactory()
        let withTools = MobileInputCatalog(catalog: conversion.catalog, tools: MobileToolFactory(
            formats: conversion.catalog, suffixes: LocalizedToolSuffixes(language: .english)).catalog)
        #expect(!withTools.accepts([URL(fileURLWithPath: "/Documents/bundle.zip")]))
        // Home leaves subtitles to Document and Text, so it shows three even rows of two.
        #expect(withTools.options.filter { $0.kind != .subtitle }.count == 6)
        let images = sut.options.first { $0.kind == .image }
        #expect(images?.contentTypes.contains(.png) == true)
        #expect(images?.contentTypes.contains(.pdf) == false)
    }

    @Test("results wait for active screens and the previous sheet's full dismissal")
    func queuedResults() {
        let sut = MobileCoordinator()
        sut.setResultsBlocked(true)
        sut.share([photo])
        #expect(sut.sharing == nil)
        sut.setResultsBlocked(false)
        #expect(sut.sharing?.urls == [photo])
        // SwiftUI clears its binding before the dismissal animation ends.
        sut.sharing = nil
        sut.share([pdf])
        #expect(sut.sharing == nil)
        sut.sharingDismissed()
        #expect(sut.sharing?.urls == [pdf])
        sut.sharingDismissed()
        #expect(sut.sharing == nil)
    }

    @Test("only library-compatible image batches offer Photos")
    func photoEligibility() {
        #expect(PhotoLibrarySaver.accepts([photo]))
        #expect(!PhotoLibrarySaver.accepts([]))
        #expect(!PhotoLibrarySaver.accepts([photo, pdf]))
        #expect(!PhotoLibrarySaver.accepts([URL(fileURLWithPath: "/Documents/icon.ico")]))
    }

    @Test("a denied or failed Photos save stays recoverable; a successful save cannot repeat")
    func saving() async {
        let denied = MobileImageSaveViewModel(saver: StubPhotoSaver(error: .permissionDenied))
        await denied.save([photo])
        #expect(denied.error == .mobilePhotosDenied && !denied.saved && !denied.isSaving)
        let failed = MobileImageSaveViewModel(saver: StubPhotoSaver(error: .unsupported))
        await failed.save([photo])
        #expect(failed.error == .mobilePhotosFailed && !failed.saved)
        let saver = StubPhotoSaver()
        let success = MobileImageSaveViewModel(saver: saver)
        await success.save([photo])
        await success.save([photo])
        #expect(success.saved && !success.isSaving && success.error == nil)
        #expect(saver.calls == 1)
    }
}

nonisolated private final class StubPhotoSaver: PhotoLibrarySaving {
    let error: PhotoLibrarySaver.SaveError?
    private(set) var calls = 0
    init(error: PhotoLibrarySaver.SaveError? = nil) { self.error = error }
    func save(_ urls: [URL]) async throws {
        calls += 1
        if let error { throw error }
    }
}
