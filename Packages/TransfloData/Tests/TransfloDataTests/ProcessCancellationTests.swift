import Foundation
import Testing
@testable import TransfloData

@Suite("Helper cancellation")
struct ProcessCancellationTests {
    /// Without the SIGKILL escalation this helper would run for its full 20 seconds. The bound is
    /// generous because parallel encoder tests can load the machine.
    @Test("a helper that ignores SIGTERM is stopped promptly")
    func ignoresTermination() async throws {
        let task = Task {
            await ProcessRunner.run(
                executable: URL(fileURLWithPath: "/bin/bash"),
                arguments: ["-c", "trap '' TERM; SECONDS=0; while (( SECONDS < 20 )); do :; done"],
                onStdoutLine: { _ in }, onStderrLine: { _ in }
            )
        }
        defer { task.cancel() }
        // Pipe output is read in blocks, so give bash a fixed head start to install its trap.
        try await Task.sleep(for: .milliseconds(500))
        let clock = ContinuousClock()
        let start = clock.now
        task.cancel()
        let status = await task.value
        #expect(status != 0)
        #expect(clock.now - start < .seconds(4))
    }
}
