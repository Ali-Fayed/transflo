import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

/// Tracks the peak number of concurrent sections.
actor PeakCounter {
    private(set) var current = 0
    private(set) var peak = 0

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave() {
        current -= 1
    }
}

@Suite("ConcurrencyGate")
struct ConcurrencyGateTests {
    @Test("never runs more than its limit at once, and runs everything")
    func limit() async throws {
        let gate = ConcurrencyGate(limit: 3)
        let counter = PeakCounter()
        try await withThrowingTaskGroup(of: Int.self) { group in
            for index in 0..<20 {
                let section: @Sendable () async throws(JobError) -> Int = {
                    await counter.enter()
                    try? await Task.sleep(for: .milliseconds(5))
                    await counter.leave()
                    return index
                }
                group.addTask { try await gate.run(section) }
            }
            var finished = 0
            for try await _ in group { finished += 1 }
            #expect(finished == 20)
        }
        #expect(await counter.peak == 3)
    }

    @Test("errors pass through and free the slot")
    func errors() async throws {
        let gate = ConcurrencyGate(limit: 1)
        await #expect(throws: JobError.failed) {
            try await gate.run { () async throws(JobError) -> Int in
                throw .failed
            }
        }
        let value = try await gate.run { () async throws(JobError) -> Int in
            7
        }
        #expect(value == 7)
    }
    @Test("a cancelled waiter exits before the occupied slot is released and never runs its body")
    func queuedCancellation() async throws {
        let gate = ConcurrencyGate(limit: 1)
        let signal = GateSignal()
        let counter = PeakCounter()
        let first = Task {
            try await gate.run { () async throws(JobError) -> Int in
                await counter.enter()
                await signal.wait()
                await counter.leave()
                return 1
            }
        }
        while await counter.current == 0 { await Task.yield() }
        let cancelled = Task {
            do {
                _ = try await gate.run { () async throws(JobError) -> Int in
                    await counter.enter()
                    return 2
                }
                return false
            } catch { return (error as? JobError) == .cancelled }
        }
        for _ in 0..<50 { await Task.yield() }
        cancelled.cancel()
        // A broken gate must fail rather than deadlock the test runner.
        let watchdog = Task {
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            await signal.open()
        }
        #expect(await cancelled.value)
        #expect(await signal.isOpen == false)
        await signal.open()
        watchdog.cancel()
        _ = try await first.value
        let next = try await gate.run { () async throws(JobError) -> Int in 3 }
        #expect(next == 3)
        #expect(await counter.current == 0)
    }
}
