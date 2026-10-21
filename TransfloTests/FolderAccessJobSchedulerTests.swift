import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Folder access")
struct FolderAccessJobSchedulerTests {
    private let photo = URL(fileURLWithPath: "/Users/me/Desktop/photo.heic")
    private let point = WheelPoint(x: 1, y: 2)
    private let toPNG = WheelOption(.format(CatalogFixtures.png))

    private func settle(_ scheduler: SpyJobScheduler, hints: SpyHints) async {
        for _ in 0..<200 where scheduler.scheduled.isEmpty && hints.shown.isEmpty { await Task.yield() }
    }

    @Test("a covered folder schedules at once without asking")
    func covered() {
        let base = SpyJobScheduler()
        let access = FakeFolderAccess(granted: [URL(fileURLWithPath: "/Users/me")])
        let sut = FolderAccessJobScheduler(base: base, access: access, hints: SpyHints())
        sut.schedule(toPNG, items: [photo], near: point)
        #expect(base.scheduled.count == 1)
        #expect(access.requested.isEmpty)
    }

    @Test("an uncovered folder is asked for once, then the job runs")
    func asksThenRuns() async {
        let base = SpyJobScheduler()
        let hints = SpyHints()
        let access = FakeFolderAccess()
        let sut = FolderAccessJobScheduler(base: base, access: access, hints: hints)
        sut.schedule(toPNG, items: [photo, URL(fileURLWithPath: "/Users/me/Desktop/other.heic")], near: point)
        await settle(base, hints: hints)
        #expect(access.requested.map(\.path) == ["/Users/me/Desktop"])
        #expect(base.scheduled.count == 1)
        #expect(hints.shown.isEmpty)
    }

    @Test("declining shows a hint and doesn't schedule the job")
    func declined() async {
        let base = SpyJobScheduler()
        let hints = SpyHints()
        let sut = FolderAccessJobScheduler(base: base, access: FakeFolderAccess(grants: false), hints: hints)
        sut.schedule(toPNG, items: [photo], near: point)
        await settle(base, hints: hints)
        #expect(base.scheduled.isEmpty)
        #expect(hints.shown == [.folderAccessDenied])
    }

    @Test("Move checks destination access even when the source folder is already granted", arguments: [true, false])
    func moveDestination(grants: Bool) async {
        let base = SpyJobScheduler()
        let hints = SpyHints()
        let destination = URL(fileURLWithPath: "/Users/me/Archive", isDirectory: true)
        let access = FakeFolderAccess(granted: [photo.deletingLastPathComponent()], grants: grants)
        let sut = FolderAccessJobScheduler(base: base, access: access, hints: hints)
        sut.schedule(WheelOption(.action(.move), settings: .destination(destination)), items: [photo], near: point)
        await settle(base, hints: hints)
        #expect(access.requested.map(\.path) == [destination.path])
        #expect(base.scheduled.count == (grants ? 1 : 0))
        #expect(hints.shown == (grants ? [] : [.folderAccessDenied]))
    }

    @Test("actions that don't write beside the file never ask")
    func readOnlyActions() {
        let base = SpyJobScheduler()
        let access = FakeFolderAccess(grants: false)
        let sut = FolderAccessJobScheduler(base: base, access: access, hints: SpyHints())
        for action in [ActionKind.airDrop, .float, .copy, .copyPath] {
            sut.schedule(WheelOption(.action(action)), items: [photo], near: point)
        }
        #expect(base.scheduled.count == 4)
        #expect(access.requested.isEmpty)
        #expect(FolderAccessJobScheduler.writesBesideOriginals(WheelOption(.action(.move))))
        #expect(FolderAccessJobScheduler.writesBesideOriginals(WheelOption(.tool(.crop))))
    }
}
