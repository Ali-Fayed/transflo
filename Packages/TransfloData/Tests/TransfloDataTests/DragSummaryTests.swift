import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

/// Filesystem metadata Strategy regression coverage; fixtures stay in a temporary directory.
struct DragSummaryTests {
    @Test func countsFilesIncludingEmptyFiles() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("one")
        let second = folder.url.appendingPathComponent("empty")
        try Data(repeating: 1, count: 123).write(to: first)
        try Data().write(to: second)
        let provider = FileDragSummaryProvider()
        #expect(provider.summary(for: [first]) == DragSummary(itemCount: 1, totalBytes: 123))
        #expect(provider.summary(for: [second]) == DragSummary(itemCount: 1, totalBytes: 0))
        #expect(provider.summary(for: [first, second]) == DragSummary(itemCount: 2, totalBytes: 123))
        #expect(provider.summary(for: []) == DragSummary(itemCount: 0, totalBytes: 0))
    }

    @Test func foldersMissingFilesAndRemoteURLsHaveUnknownSize() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let missing = folder.url.appendingPathComponent("missing")
        let provider = FileDragSummaryProvider()
        #expect(provider.summary(for: [folder.url]).totalBytes == nil)
        #expect(provider.summary(for: [missing, folder.url]).itemCount == 2)
        #expect(provider.summary(for: [missing]).totalBytes == nil)
        let remote = try #require(URL(string: "https://example.com/file"))
        #expect(provider.summary(for: [remote]).totalBytes == nil)
    }

    @Test func summaryRejectsInvalidCountsAndSizes() {
        #expect(DragSummary(itemCount: -1, totalBytes: -2) == DragSummary(itemCount: 0, totalBytes: nil))
    }
}
