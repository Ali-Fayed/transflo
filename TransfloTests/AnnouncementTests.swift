import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("VoiceOver announcements")
struct AnnouncementTests {
    private let photo = URL(fileURLWithPath: "/tmp/photo.heic")
    private let english = Localizer(language: .english)

    private func record(_ state: JobState, items: [URL]? = nil) -> JobRecord {
        JobRecord(id: UUID(), option: WheelOption(.format(CatalogFixtures.png)), items: items ?? [photo],
                  origin: WheelPoint(x: 0, y: 0), state: state)
    }

    @Test("finished jobs name the operation and the files; failures say why")
    func texts() {
        #expect(JobPresentation.announcement(for: record(.succeeded(outputs: [])), localizer: english)
            == "Convert to PNG finished: photo.heic")
        #expect(JobPresentation.announcement(for: record(.succeeded(outputs: []), items: [photo, photo]),
                                             localizer: english) == "Convert to PNG finished: 2 files")
        #expect(JobPresentation.announcement(for: record(.failed(.sourceMissing)), localizer: english)
            == "Convert to PNG failed: \(english.string(.errorSourceMissing))")
    }

    @Test("cancelled and unfinished jobs stay quiet")
    func quiet() {
        for state in [JobState.failed(.cancelled), .queued, .running(fraction: 0.5)] {
            #expect(JobPresentation.announcement(for: record(state), localizer: english) == nil)
        }
    }

    @Test("the job center announces each job as it ends")
    func center() async {
        let runner = GatedJobRunner()
        let announcer = SpyAnnouncer()
        let sut = JobCenter(runOption: RunWheelOptionUseCase(runner: runner), hud: SpyJobHUD(), notifier: SpyNotifier(),
                            revealer: SpyRevealer(), localizer: english, announcer: announcer)
        sut.schedule(WheelOption(.format(CatalogFixtures.png)), items: [photo], near: WheelPoint(x: 0, y: 0))
        for _ in 0..<200 where runner.startedCount < 1 { await Task.yield() }
        runner.release(.success([photo]))
        await sut.waitUntilIdle()
        #expect(announcer.messages == ["Convert to PNG finished: photo.heic"])
    }
}
