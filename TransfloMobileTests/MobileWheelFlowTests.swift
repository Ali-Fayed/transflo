import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport
@testable import TransfloMobile

@Suite("Mobile wheel flow")
struct MobileWheelFlowTests {
    private let photo = URL(fileURLWithPath: "/Documents/import/photo.heic")
    private let formats = ["png", "jpg", "tiff", "bmp", "avif", "pdf", "ico", "icns"].map {
        WheelOption(.format(FormatDescriptor(id: FormatID($0), displayName: $0.uppercased(), extensions: [$0],
                                             family: .image)))
    }

    private struct SUT {
        let presenter: MobileWheelPresenter
        let coordinator: WheelCoordinator
        let scheduler: SpyJobScheduler
    }

    private func makeSUT(language: AppLanguage = .english) -> SUT {
        let localizer = Localizer(language: language)
        let viewModel = WheelViewModel(bindings: WheelKeyBindings([:]), layout: localizer)
        let presenter = MobileWheelPresenter()
        let scheduler = SpyJobScheduler()
        let choices = MobileWheelChoices(markupEditors: StubMarkupEditors())
        let coordinator = WheelCoordinator(
            resolveOptions: ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([.convert: formats])),
            presenter: presenter, viewModel: viewModel, scheduler: scheduler, editor: choices, preparer: choices
        )
        return SUT(presenter: presenter, coordinator: coordinator, scheduler: scheduler)
    }

    @Test("tapping the top wedge runs its option on the imported files", arguments: [AppLanguage.english, .arabic])
    func tapRuns(language: AppLanguage) {
        // Given the wheel open for an imported photo
        let sut = makeSUT(language: language)
        #expect(sut.coordinator.openForKeyboard(items: [photo], at: WheelPoint(x: 0, y: 0)))
        #expect(sut.presenter.isShown)
        // When the top wedge is tapped (straight up from the center)
        #expect(sut.presenter.tap(at: WheelPoint(x: 0, y: 110)))
        // Then its option runs on the photo and the wheel closes
        #expect(sut.scheduler.scheduled.map(\.option) == [formats[0]])
        #expect(sut.scheduler.scheduled.first?.items == [photo])
        #expect(!sut.presenter.isShown)
    }

    @Test("a tap on the hub closes the wheel without running anything")
    func hubCloses() {
        let sut = makeSUT()
        sut.coordinator.openForKeyboard(items: [photo], at: WheelPoint(x: 0, y: 0))
        #expect(!sut.presenter.tap(at: WheelPoint(x: 0, y: 0)))
        #expect(sut.scheduler.scheduled.isEmpty && !sut.presenter.isShown)
    }

    @Test("switching to a wheel without options keeps the current one; dismiss closes it")
    func switchAndDismiss() {
        let sut = makeSUT()
        sut.coordinator.openForKeyboard(items: [photo], at: WheelPoint(x: 0, y: 0))
        sut.coordinator.switchWheel(to: .tools)
        #expect(sut.presenter.isShown)
        sut.coordinator.dismiss()
        #expect(!sut.presenter.isShown && sut.scheduler.scheduled.isEmpty)
    }

    @Test("list selection validates the option and schedules once, without coordinates")
    func listSelection() {
        let sut = makeSUT()
        sut.coordinator.openForKeyboard(items: [photo], at: WheelPoint(x: 0, y: 0))
        #expect(sut.coordinator.options(for: .convert) == formats)
        #expect(!sut.coordinator.select(WheelOption(.tool(.trim))))
        #expect(sut.presenter.isShown && sut.scheduler.scheduled.isEmpty)
        #expect(sut.coordinator.select(formats[7]))
        #expect(!sut.coordinator.select(formats[7]))
        #expect(sut.scheduler.scheduled.count == 1)
        #expect(sut.scheduler.scheduled.first?.option == formats.last)
        #expect(sut.scheduler.scheduled.first?.items == [photo])
    }
}
