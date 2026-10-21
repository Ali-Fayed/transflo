import TransfloDomain

/// Validates a `CatalogDTO` and expands it into a `ConversionCatalog`.
enum CatalogMapper {
    static let supportedVersion = 1

    static func catalog(from dto: CatalogDTO) throws(CatalogError) -> ConversionCatalog {
        guard dto.version == supportedVersion else { throw .invalid(reason: "unsupported version \(dto.version)") }
        let formats = try dto.formats.map(format(from:))
        try ensureUnique(formats.map(\.id.rawValue), what: "format id")
        try ensureUnique(formats.flatMap(\.extensions), what: "extension")
        let known = Set(formats.map(\.id))
        var paths: [ConversionPath] = []
        for rule in dto.conversions {
            guard !rule.engines.isEmpty else { throw .invalid(reason: "rule without engines") }
            for source in rule.from.map(FormatID.init) {
                for target in rule.to.map(FormatID.init) where target != source {
                    guard known.contains(source), known.contains(target) else {
                        throw .invalid(reason: "unknown format in \(source) → \(target)")
                    }
                    let engines = rule.engines.map(EngineID.init)
                    paths.append(ConversionPath(source: source, target: target, engines: engines))
                }
            }
        }
        try ensureUnique(paths.map { "\($0.source)→\($0.target)" }, what: "conversion")
        return ConversionCatalog(formats: formats, paths: paths)
    }

    private static func format(from dto: CatalogFormatDTO) throws(CatalogError) -> FormatDescriptor {
        guard let family = family(from: dto.family) else { throw .invalid(reason: "unknown family \(dto.family)") }
        guard !dto.extensions.isEmpty else { throw .invalid(reason: "\(dto.id) has no extensions") }
        return FormatDescriptor(id: FormatID(dto.id), displayName: dto.name, extensions: dto.extensions, family: family)
    }

    static func family(from value: String) -> FormatFamily? {
        switch value {
        case "image": .image
        case "audio": .audio
        case "video": .video
        case "document": .document
        case "presentation": .presentation
        case "spreadsheet": .spreadsheet
        case "subtitle": .subtitle
        case "archive": .archive
        default: nil
        }
    }

    private static func ensureUnique(_ values: [String], what: String) throws(CatalogError) {
        var seen = Set<String>()
        for value in values where !seen.insert(value.lowercased()).inserted {
            throw .invalid(reason: "duplicate \(what) \(value)")
        }
    }
}
