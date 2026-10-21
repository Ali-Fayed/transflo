import Foundation

/// What is in an image or document, read on device (Vision).
public protocol ImageUnderstanding: Sendable {
    /// The most confident subject labels ("beach", "dog"), best first.
    func labels(for url: URL) async throws(JobError) -> [String]
    /// Text found in the file, in reading order; empty when there is none.
    func text(in url: URL) async throws(JobError) -> String
}
