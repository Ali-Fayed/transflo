import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// A tool engine that accepts a fixed set of tools and records requests.
public final class FakeToolEngine: ToolEngine, @unchecked Sendable {
    private let tools: Set<ToolKind>
    private let result: Result<[URL], JobError>
    private let lock = NSLock()
    private var requests: [ToolRequest] = []

    public init(tools: Set<ToolKind>, result: Result<[URL], JobError> = .success([])) {
        self.tools = tools
        self.result = result
    }

    public var receivedRequests: [ToolRequest] { lock.withLock { requests } }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        tools.contains(tool)
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        lock.withLock { requests.append(request) }
        return try result.get()
    }
}
