import Foundation

/// Runs Tools-wheel jobs: recognizes the files, picks a capable engine and applies the
/// option's settings (or the tool's defaults).
public struct ToolJobRunner: WheelJobRunning {
    private let formats: ConversionCatalog
    private let engines: [any ToolEngine]

    public init(formats: ConversionCatalog, engines: [any ToolEngine]) {
        self.formats = formats
        self.engines = engines
    }

    public func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard case .tool(let tool) = option.kind else { throw .unsupported }
        if Task.isCancelled { throw .cancelled }
        let toolItems = items.map { ToolItem(url: $0, format: formats.format(forFileExtension: $0.pathExtension)) }
        let itemFormats = toolItems.map(\.format)
        guard let engine = engines.first(where: { $0.canRun(tool, on: itemFormats) }) else { throw .unsupported }
        let request = ToolRequest(tool: tool, settings: option.settings ?? .defaults(for: tool), items: toolItems)
        let outputs = try await engine.run(request, progress: progress)
        progress(1)
        return outputs
    }
}
