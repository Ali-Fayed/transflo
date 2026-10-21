/// The tools Transflo offers, in wheel order (Registry pattern).
public struct ToolCatalog: Sendable, Equatable {
    public let tools: [ToolDescriptor]

    public init(tools: [ToolDescriptor]) {
        self.tools = tools
    }

    public func descriptor(for kind: ToolKind) -> ToolDescriptor? {
        tools.first { $0.kind == kind }
    }

    /// Tools that accept every file in a drag. `formats` holds each file's format, `nil` when unknown.
    public func tools(for formats: [FormatDescriptor?]) -> [ToolDescriptor] {
        guard !formats.isEmpty else { return [] }
        return tools.filter { tool in
            if tool.requiresMultipleFiles && formats.count < 2 { return false }
            return formats.allSatisfy(tool.accepts)
        }
    }

    /// Removes tools unavailable on every format. The options provider additionally checks
    /// engine capabilities against the actual dragged selection.
    public func restricted(to engines: [any ToolEngine], formats: [FormatDescriptor]) -> ToolCatalog {
        ToolCatalog(tools: tools.filter { tool in
            let samples: [FormatDescriptor?] = tool.appliesToAnyFile ? [nil] : formats.filter(tool.accepts)
            return samples.contains { sample in
                let batch = Array(repeating: sample, count: tool.requiresMultipleFiles ? 2 : 1)
                return engines.contains { $0.canRun(tool.kind, on: batch) }
            }
        })
    }
}
