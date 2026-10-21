import Foundation
import Testing
@testable import TransfloMobile

@Suite("Mobile jobs and sharing")
struct MobileJobsAndSharingTests {
    private let result = URL(fileURLWithPath: "/Documents/photo.jpg")

    @Test("the banner shows a job, then hides once it has finished")
    func banner() async throws {
        // Given a banner that keeps finished jobs for a moment
        let sut = MobileJobBanner(visibleFor: .milliseconds(20))
        let id = UUID()
        // When a job starts and finishes
        sut.present(id)
        #expect(sut.jobID == id)
        sut.jobFinished(id)
        #expect(sut.jobID == id)
        // Then it's gone (polled, so a busy simulator doesn't make the test flaky)
        for _ in 0..<40 where sut.jobID != nil { try await Task.sleep(for: .milliseconds(50)) }
        #expect(sut.jobID == nil)
    }

    @Test("a newer job keeps the banner, and another job finishing doesn't hide it")
    func replaced() async throws {
        let sut = MobileJobBanner(visibleFor: .milliseconds(20))
        let first = UUID(), second = UUID()
        sut.present(first)
        sut.jobFinished(first)
        sut.present(second)
        sut.jobFinished(first)
        try await Task.sleep(for: .milliseconds(200))
        #expect(sut.jobID == second)
        sut.dismiss()
        #expect(sut.jobID == nil)
    }

    @Test("a job shows centered until hidden, and the next job shows centered again")
    func minimized() {
        let sut = MobileJobBanner()
        sut.present(UUID())
        #expect(!sut.isMinimized)
        sut.minimize()
        #expect(sut.isMinimized)
        sut.present(UUID())
        #expect(!sut.isMinimized)
    }

    @Test("sharing results raises the share sheet; nothing to share raises nothing")
    func share() {
        let sut = MobileCoordinator()
        sut.share([])
        #expect(sut.sharing == nil)
        sut.share([result])
        #expect(sut.sharing?.urls == [result])
    }

    @Test("Jobs opens once even when asked twice")
    func jobs() {
        let sut = MobileCoordinator()
        sut.showJobs()
        sut.showJobs()
        #expect(sut.selectedTab == .jobs)
    }

    @Test("revealing results hands them to the share sheet on the main actor")
    func revealer() async throws {
        let coordinator = MobileCoordinator()
        let sut = MobileShareRevealer { coordinator.share($0) }
        sut.reveal([])
        sut.reveal([result])
        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.sharing?.urls == [result])
    }
}
