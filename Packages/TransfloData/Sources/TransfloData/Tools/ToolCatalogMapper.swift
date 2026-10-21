import TransfloDomain

/// Validates `tools.json` and maps it to a `ToolCatalog`.
enum ToolCatalogMapper {
    static func catalog(from dto: ToolCatalogDTO) throws(CatalogError) -> ToolCatalog {
        guard dto.version == 1 else { throw .invalid(reason: "unsupported tools version \(dto.version)") }
        var seen = Set<ToolKind>()
        var tools: [ToolDescriptor] = []
        for entry in dto.tools {
            guard let kind = ToolKind(rawValue: entry.kind) else {
                throw .invalid(reason: "unknown tool \(entry.kind)")
            }
            guard seen.insert(kind).inserted else { throw .invalid(reason: "duplicate tool \(entry.kind)") }
            var families = Set<FormatFamily>()
            for name in entry.families {
                guard let family = CatalogMapper.family(from: name) else {
                    throw .invalid(reason: "unknown family \(name)")
                }
                families.insert(family)
            }
            let anyFile = entry.anyFile ?? false
            guard anyFile || !families.isEmpty || !entry.formats.isEmpty else {
                throw .invalid(reason: "\(entry.kind) accepts nothing")
            }
            tools.append(ToolDescriptor(
                kind: kind,
                families: families,
                formats: Set(entry.formats.map(FormatID.init)),
                appliesToAnyFile: anyFile,
                requiresMultipleFiles: entry.multiple ?? false,
                isInteractive: entry.interactive ?? false
            ))
        }
        return ToolCatalog(tools: tools)
    }
}
