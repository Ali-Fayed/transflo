import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Wheel ordering in Settings and jobs")
struct WheelOrderingTests {
    private func makeModel(_ usage: InMemoryWheelUsageRepository?) -> WheelVisibilityViewModel {
        WheelVisibilityViewModel(
            choices: ListWheelChoicesUseCase(catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog),
            repository: InMemoryWheelVisibilityRepository(), usage: usage
        )
    }

    @Test("stars and ordering switches are saved for the wheel to read")
    func settingsSaveUsage() throws {
        let repository = InMemoryWheelUsageRepository()
        let sut = makeModel(repository)
        sut.select(.tools)
        let row = try #require(sut.groups.first?.rows.first)
        #expect(sut.supportsOrdering && !sut.isPinned(row))
        sut.setPinned(row, true)
        sut.setLastUsedFirst(false)
        sut.setOrdersByFrequency(true)
        let saved = repository.loadWheelUsage()
        #expect(saved.isPinned(row.option) && !saved.lastUsedFirst && saved.ordersByFrequency)
        sut.setPinned(row, false)
        #expect(!repository.loadWheelUsage().isPinned(row.option))
    }

    @Test("without somewhere to save, ordering controls are not offered")
    func noRepository() {
        #expect(!makeModel(nil).supportsOrdering)
    }

    @Test("scheduling a job records its option as the wheel's last choice")
    func jobsRecordUsage() async {
        let repository = InMemoryWheelUsageRepository()
        let runner = GatedJobRunner()
        let center = JobCenter(runOption: RunWheelOptionUseCase(runner: runner), hud: SpyJobHUD(),
                               notifier: SpyNotifier(), revealer: SpyRevealer(),
                               localizer: Localizer(language: .english),
                               usage: RecordWheelUsageUseCase(repository: repository))
        let compress = WheelOption(.tool(.compress))
        center.schedule(compress, items: [URL(fileURLWithPath: "/tmp/a.png")], near: WheelPoint(x: 0, y: 0))
        #expect(repository.loadWheelUsage().counts[compress.id] == 1)
        for _ in 0..<200 where runner.startedCount < 1 { await Task.yield() }
        _ = runner.release(.success([]))
        await center.waitUntilIdle()
    }
}
