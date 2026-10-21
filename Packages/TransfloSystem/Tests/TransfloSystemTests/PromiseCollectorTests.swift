import Foundation
import Testing
@testable import TransfloSystem

@MainActor @Suite("Promised file aggregation")
struct PromiseCollectorTests {
    @Test func waitsForEveryFileAndOrdersAcrossReceivers() async throws {
        var batches: [[URL]] = []
        let collector = PromiseCollector(expected: 2) { batches.append($0) }
        let first = URL(fileURLWithPath: "/tmp/a.png")
        let second = URL(fileURLWithPath: "/tmp/b.png")
        let third = URL(fileURLWithPath: "/tmp/c.png")
        // Callbacks can arrive before the receiver's filenames have been read.
        collector.add(second, receiver: 0)
        collector.expect(["a.png", "b.png"], from: 0)
        collector.expect(["c.png"], from: 1)
        collector.add(third, receiver: 1)
        await Task.yield()
        #expect(batches.isEmpty)
        collector.add(first, receiver: 0)
        for _ in 0..<100 where batches.isEmpty { await Task.yield() }
        #expect(batches == [[first, second, third]])
        collector.add(first, receiver: 0)
        await Task.yield()
        #expect(batches.count == 1)
    }

    @Test func failedPromiseDoesNotDeliverAnIncompleteSelection() async {
        var batches: [[URL]] = []
        let collector = PromiseCollector(expected: 1) { batches.append($0) }
        collector.expect(["a.png", "b.png"], from: 0)
        collector.add(URL(fileURLWithPath: "/tmp/a.png"), receiver: 0)
        collector.add(nil, receiver: 0)
        for _ in 0..<100 where batches.isEmpty { await Task.yield() }
        #expect(batches == [[]])
    }
}
