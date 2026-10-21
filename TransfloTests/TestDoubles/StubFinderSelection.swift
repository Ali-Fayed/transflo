import Foundation
import TransfloDomain

/// Returns a fixed selection or error.
nonisolated struct StubFinderSelection: FinderSelectionReading {
    let result: Result<[URL], JobError>

    func selection() async throws(JobError) -> [URL] {
        try result.get()
    }
}
