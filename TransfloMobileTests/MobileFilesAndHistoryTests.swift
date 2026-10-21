import Foundation
import Testing
import TransfloDomain
@testable import TransfloMobile

@Suite("Mobile files and history")
struct MobileFilesAndHistoryTests {
    private let photo = URL(fileURLWithPath: "/Documents/import/photo.heic")
    private let result = URL(fileURLWithPath: "/Documents/import/photo (compress).jpg")
    private var folder: WorkspaceFolder {
        WorkspaceFolder(url: URL(fileURLWithPath: "/Documents/import"), created: .now, files: [
            WorkspaceFile(url: result, bytes: 10, modified: .now), WorkspaceFile(url: photo, bytes: 20, modified: .now)
        ])
    }

    @Test("Files lists the workspace, converts with the wheel and shares what's chosen")
    func files() async {
        // Given a workspace with one import
        let wheel = SpyWheelOpener()
        var shared: [[URL]] = []
        let sut = MobileFilesViewModel(workspace: FakeWorkspace([folder]), wheel: wheel) { shared.append($0) }
        // When it loads, a file is converted and shared
        await sut.reload()
        sut.convert([photo])
        sut.shareFiles([result])
        // Then the wheel opened for it and the share sheet got the result
        #expect(sut.folders.count == 1 && wheel.opened == [[photo]])
        #expect(shared == [[result]] && sut.message == nil)
    }

    @Test("files nothing can handle, unreadable workspaces and failed deletes say so")
    func failures() async {
        let refusing = MobileFilesViewModel(workspace: FakeWorkspace([folder]),
                                            wheel: SpyWheelOpener(hasOptions: false), share: { _ in })
        refusing.convert([photo])
        #expect(refusing.message == .mobileNoOptions)
        let unreadable = MobileFilesViewModel(workspace: FakeWorkspace([], failReads: true), wheel: SpyWheelOpener(),
                                              share: { _ in })
        await unreadable.reload()
        #expect(unreadable.message == .mobileFilesUnreadable)
        let stuck = MobileFilesViewModel(workspace: FakeWorkspace([folder], failDeletes: true), wheel: SpyWheelOpener(),
                                         share: { _ in })
        await stuck.delete([photo])
        #expect(stuck.message == .mobileDeleteFailed)
    }

    @Test("deleting removes files and drops them from the selection")
    func delete() async {
        let sut = MobileFilesViewModel(workspace: FakeWorkspace([folder]), wheel: SpyWheelOpener(), share: { _ in })
        await sut.reload()
        sut.selection = [photo, result]
        await sut.delete([photo])
        #expect(sut.folders.first?.files.map(\.url) == [result])
        #expect(sut.selection == [result])
    }

    @Test("a finished job is remembered with outputs relative to the workspace; Clear forgets it")
    func history() {
        let store = InMemoryJobHistory()
        var shared: [[URL]] = []
        let root = URL(fileURLWithPath: "/Documents")
        let sut = MobileHistoryViewModel(repository: store, root: root, share: { shared.append($0) })
        let outside = URL(fileURLWithPath: "/elsewhere/x")
        let job = JobRecord(id: UUID(), option: WheelOption(.tool(.compress)), items: [photo],
                            origin: WheelPoint(x: 0, y: 0), state: .succeeded(outputs: [result, outside]))
        sut.finished(job)
        #expect(sut.entries.first?.outputs == ["import/photo (compress).jpg"])
        #expect(sut.earlier(excluding: [job.id]).isEmpty && sut.earlier(excluding: []).count == 1)
        #expect(JobHistoryMapper.content(sut.entries[0].files) == .verbatim("photo.heic"))
        sut.clear()
        #expect(sut.entries.isEmpty && store.load().isEmpty)
    }

    @Test("deleting one Activity entry forgets only it; deleting an unknown entry changes nothing")
    func deleteEntry() {
        let store = InMemoryJobHistory()
        let sut = MobileHistoryViewModel(repository: store, root: URL(fileURLWithPath: "/Documents"), share: { _ in })
        let jobs = (0..<2).map { _ in
            JobRecord(id: UUID(), option: WheelOption(.tool(.compress)), items: [photo],
                      origin: WheelPoint(x: 0, y: 0), state: .succeeded(outputs: [result]))
        }
        jobs.forEach(sut.finished)
        sut.delete(UUID())
        #expect(sut.entries.count == 2)
        sut.delete(jobs[0].id)
        #expect(sut.entries.map(\.id) == [jobs[1].id] && store.load().map(\.id) == [jobs[1].id])
    }

    @Test("stored text with a key this version doesn't know falls back to its verbatim value")
    func unknownKey() {
        #expect(JobHistoryMapper.content(.init(key: "no.such.key", verbatim: "x")) == .verbatim("x"))
        #expect(JobHistoryMapper.content(.init(key: "tool.compress")) == .key(.toolCompress))
    }
}
