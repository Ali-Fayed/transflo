import Foundation
import TransfloDomain

/// A controllable rendering Strategy for success, failure and cancelled preview work.
public actor FakeBackgroundPreviewRenderer: BackgroundPreviewRendering {
    private let output: Data
    private let delay: Duration
    private var failure: JobError?
    public private(set) var renderedStyles: [BackgroundStyle] = []

    public init(output: Data = Data([1]), delay: Duration = .zero, failure: JobError? = nil) {
        self.output = output
        self.delay = delay
        self.failure = failure
    }

    public func render(_ thumbnail: Data, style: BackgroundStyle) async throws(JobError) -> Data {
        renderedStyles.append(style)
        do { try await Task.sleep(for: delay) } catch { throw .cancelled }
        if let failure { throw failure }
        return output
    }

    public func setFailure(_ failure: JobError?) { self.failure = failure }
}
