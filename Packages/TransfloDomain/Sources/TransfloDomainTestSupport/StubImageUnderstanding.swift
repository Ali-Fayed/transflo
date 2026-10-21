import Foundation
import TransfloDomain

/// Returns fixed labels and text per file name (falling back to `labels` / `text`), or `error`.
public struct StubImageUnderstanding: ImageUnderstanding {
    public var labels: [String]
    public var text: String
    public var textByName: [String: String]
    public var error: JobError?

    public init(labels: [String] = [], text: String = "", textByName: [String: String] = [:], error: JobError? = nil) {
        self.labels = labels
        self.text = text
        self.textByName = textByName
        self.error = error
    }

    public func labels(for url: URL) async throws(JobError) -> [String] {
        if let error { throw error }
        return labels
    }

    public func text(in url: URL) async throws(JobError) -> String {
        if let error { throw error }
        return textByName[url.lastPathComponent] ?? text
    }
}
