import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

struct WheelSummaryTests {
    @Test func hubSummaryUsesInjectedFormatterAndFallsBackForUnknownSize() {
        let localizer = Localizer(language: .english)
        let model = WheelViewModel(bindings: .standard, layout: localizer,
                                   byteFormatter: StubByteSizeFormatter(), localizer: localizer)
        let options = [WheelOption(.action(.copy))]
        model.show(.actions, options: options, summary: DragSummary(itemCount: 1, totalBytes: 0))
        #expect(model.hubDetail == "size-0")
        model.show(.actions, options: options, summary: DragSummary(itemCount: 2, totalBytes: 123))
        #expect(model.hubDetail?.contains("size-123") == true)
        model.show(.tools, options: options, summary: DragSummary(itemCount: 2, totalBytes: nil))
        #expect(model.hubDetail == nil)
        #expect(model.hubTitle == .wheelTools)
        model.reset()
        #expect(model.state.summary == nil)
    }

    @Test func fileSizeFormattingUsesTheChosenLanguage() {
        let formatter = FileByteSizeFormatter()
        #expect(formatter.string(bytes: 2_400_000, locale: Locale(identifier: "en")).contains("2.4"))
        let arabic = formatter.string(bytes: 2_400_000, locale: Locale(identifier: "ar"))
        #expect(arabic.contains("٢"))
        #expect(!arabic.contains("2"))
        #expect(formatter.string(bytes: 0, locale: Locale(identifier: "en")).contains("0"))
    }

    @Test func summaryIsComputedOncePerDragAndKeyboardSession() {
        let provider = SpyDragSummaryProvider()
        let model = WheelViewModel(bindings: .standard, layout: StubLayoutDirection())
        let coordinator = WheelCoordinator(
            resolveOptions: ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([
                .convert: [WheelOption(.format(CatalogFixtures.png))], .tools: [WheelOption(.tool(.crop))]
            ])), presenter: SpyWheelPresenter(), viewModel: model, scheduler: SpyJobScheduler(),
            editor: SpyToolEditor(), preparer: SpyActionPreparer(), summaryProvider: provider
        )
        let file = URL(fileURLWithPath: "/tmp/file.jpg")
        let point = WheelPoint(x: 100, y: 100)
        coordinator.handle(.began(items: [file]))
        coordinator.handle(.wheelRequested(.convert, at: point))
        coordinator.handle(.wheelRequested(.tools, at: point))
        model.updatePointer(WheelPoint(x: 0, y: 100))
        #expect(provider.calls == 1)
        #expect(model.state.summary?.totalBytes == 1200)
        #expect(coordinator.openForKeyboard(items: [file, file], at: point))
        #expect(provider.calls == 2)
        #expect(model.state.summary?.itemCount == 2)
    }
}
