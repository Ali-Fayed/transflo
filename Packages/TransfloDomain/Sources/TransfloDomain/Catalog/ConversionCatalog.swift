/// Every format and conversion path the app offers (Registry pattern).
public struct ConversionCatalog: Sendable, Equatable {
    public let formats: [FormatDescriptor]
    public let paths: [ConversionPath]
    private let formatsByID: [FormatID: FormatDescriptor]
    private let formatsByExtension: [String: FormatDescriptor]
    private let pathsByRoute: [Route: ConversionPath]

    private struct Route: Hashable {
        let source: FormatID
        let target: FormatID
    }

    /// Callers validate input first (see `CatalogMapper`); later duplicates are ignored here.
    public init(formats: [FormatDescriptor], paths: [ConversionPath]) {
        self.formats = formats
        self.paths = paths
        var byID: [FormatID: FormatDescriptor] = [:]
        var byExtension: [String: FormatDescriptor] = [:]
        for format in formats {
            byID[format.id] = byID[format.id] ?? format
            for fileExtension in format.extensions {
                byExtension[fileExtension] = byExtension[fileExtension] ?? format
            }
        }
        var byRoute: [Route: ConversionPath] = [:]
        for path in paths {
            let route = Route(source: path.source, target: path.target)
            byRoute[route] = byRoute[route] ?? path
        }
        formatsByID = byID
        formatsByExtension = byExtension
        pathsByRoute = byRoute
    }

    public func format(_ id: FormatID) -> FormatDescriptor? {
        formatsByID[id]
    }

    /// The format for a file extension (case-insensitive), or `nil` when unknown.
    public func format(forFileExtension fileExtension: String) -> FormatDescriptor? {
        formatsByExtension[fileExtension.lowercased()]
    }

    /// Targets reachable from `source`, in catalog order.
    public func targets(from source: FormatID) -> [FormatDescriptor] {
        paths.filter { $0.source == source }.compactMap { formatsByID[$0.target] }
    }

    public func path(from source: FormatID, to target: FormatID) -> ConversionPath? {
        pathsByRoute[Route(source: source, target: target)]
    }

    /// Only the paths at least one of `engines` can perform on this system, so the wheel never
    /// offers a conversion that would fail (e.g. WebP output when ffmpeg is not bundled).
    public func restricted(to engines: [any ConversionEngine]) -> ConversionCatalog {
        let byID = Dictionary(engines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let available = paths.filter { path in
            guard let source = formatsByID[path.source], let target = formatsByID[path.target] else { return false }
            return path.engines.contains { byID[$0]?.canConvert(from: source, to: target) == true }
        }
        return ConversionCatalog(formats: formats, paths: available)
    }
}
