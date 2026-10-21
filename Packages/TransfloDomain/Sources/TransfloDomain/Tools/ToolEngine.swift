import Foundation

/// Runs tools for some kinds of files (Strategy pattern).
public protocol ToolEngine: Sendable {
    /// Whether this engine can run `tool` on files of these formats on the running system.
    func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool

    /// Runs the tool and returns the files it wrote (none for tools like Read QR).
    /// Must not modify the inputs, and must remove its partial outputs if it fails.
    func run(_ request: ToolRequest, progress: @escaping @Sendable (Double) -> Void) async throws(JobError) -> [URL]
}
