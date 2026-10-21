import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("iWork app launcher")
struct IWorkAppLauncherTests {
    @Test("a closed app is opened for the export and quit afterwards")
    func opensAndQuits() async throws {
        let runtime = FakeIWorkRuntime()
        let sut = IWorkAppLauncher(runtime: runtime)
        let value = try await sut.withApp(.pages) { () async throws(JobError) in
            #expect(runtime.isRunning(.pages))
            return 7
        }
        #expect(value == 7)
        #expect(runtime.launches == [.pages] && runtime.quits == [.pages])
    }

    @Test("an app the user already had open is used and left open")
    func leavesUsersAppOpen() async throws {
        let runtime = FakeIWorkRuntime(running: [.keynote])
        try await IWorkAppLauncher(runtime: runtime).withApp(.keynote) { () async throws(JobError) in () }
        #expect(runtime.launches.isEmpty && runtime.quits.isEmpty)
    }

    @Test("concurrent exports share one launch, and the app quits after the last one")
    func sharesOneLaunch() async throws {
        let runtime = FakeIWorkRuntime()
        let sut = IWorkAppLauncher(runtime: runtime)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask { try await Self.export(with: sut, checking: runtime) }
            }
            try await group.waitForAll()
        }
        #expect(runtime.launches == [.numbers] && runtime.quits == [.numbers])
    }

    private static func export(with sut: IWorkAppLauncher, checking runtime: FakeIWorkRuntime) async throws {
        try await sut.withApp(.numbers) {
            try? await Task.sleep(for: .milliseconds(50))
            #expect(runtime.quits.isEmpty)
        }
    }

    @Test("a failed launch fails the export without running it or quitting anything")
    func launchFailure() async {
        let runtime = FakeIWorkRuntime(launchError: .failed)
        let sut = IWorkAppLauncher(runtime: runtime)
        await #expect(throws: JobError.failed) {
            try await sut.withApp(.pages) { () async throws(JobError) in Issue.record("export ran") }
        }
        #expect(runtime.quits.isEmpty)
    }

    @Test("a failed export still quits the app Transflo opened")
    func exportFailure() async {
        let runtime = FakeIWorkRuntime()
        await #expect(throws: JobError.automationDenied) {
            try await IWorkAppLauncher(runtime: runtime).withApp(.pages) { () async throws(JobError) in
                throw .automationDenied
            }
        }
        #expect(runtime.quits == [.pages])
    }
}

// @unchecked: all mutable state is guarded by `lock`.
private final class FakeIWorkRuntime: IWorkAppRuntime, @unchecked Sendable {
    private let lock = NSLock()
    private var runningApps: Set<IWorkApp>
    private var launched: [IWorkApp] = []
    private var quitted: [IWorkApp] = []
    private let launchError: JobError?

    init(running: Set<IWorkApp> = [], launchError: JobError? = nil) {
        self.runningApps = running
        self.launchError = launchError
    }

    var launches: [IWorkApp] { lock.withLock { launched } }
    var quits: [IWorkApp] { lock.withLock { quitted } }

    func isRunning(_ app: IWorkApp) -> Bool { lock.withLock { runningApps.contains(app) } }

    func launch(_ app: IWorkApp) async throws(JobError) {
        if let launchError { throw launchError }
        lock.withLock {
            launched.append(app)
            runningApps.insert(app)
        }
    }

    func quit(_ app: IWorkApp) {
        lock.withLock {
            quitted.append(app)
            runningApps.remove(app)
        }
    }
}
