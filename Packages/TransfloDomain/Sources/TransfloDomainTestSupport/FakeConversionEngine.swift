import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// A conversion engine that records requests, reports progress and returns a scripted result.
public final class FakeConversionEngine: ConversionEngine, @unchecked Sendable {
    public let id: EngineID
    private let isCapable: Bool
    private let failure: JobError?
    private let lock = NSLock()
    private var requests: [ConversionRequest] = []

    public init(id: EngineID, isCapable: Bool = true, failure: JobError? = nil) {
        self.id = id
        self.isCapable = isCapable
        self.failure = failure
    }

    public var receivedRequests: [ConversionRequest] { lock.withLock { requests } }

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        isCapable
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        lock.withLock { requests.append(request) }
        progress(0.5)
        if let failure { throw failure }
        progress(1)
        return [request.destination]
    }
}
