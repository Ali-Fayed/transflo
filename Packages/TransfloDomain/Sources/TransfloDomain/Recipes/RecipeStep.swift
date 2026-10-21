/// One step of a `Recipe`. Each maps to an existing wheel option, so it behaves exactly as that option.
public enum RecipeStep: Sendable, Hashable, Codable {
    /// Convert to the format with this catalog ID (`jpg`, `pdf`, `mp4`…).
    case convert(formatID: String)
    /// Compress with the Output Defaults chosen in Settings.
    case compress
    /// Scale images down so the longer side is at most this many pixels, at the best quality.
    case resizeLongEdge(Int)
    case removeMetadata
    /// Rename with a pattern such as `{name}-web` or `Trip {n}`; only as the last step.
    case rename(pattern: String)

    public static let longEdgeRange = 64...16_384

    var isRename: Bool {
        if case .rename = self { true } else { false }
    }

    var isValid: Bool {
        switch self {
        case .convert(let id): !id.isEmpty
        case .compress, .removeMetadata: true
        case .resizeLongEdge(let edge): Self.longEdgeRange.contains(edge)
        case .rename(let pattern): !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// The wheel option this step runs as, for the file at `index` (rename numbers from 1).
    func option(catalog: ConversionCatalog, index: Int) -> WheelOption? {
        switch self {
        case .convert(let id): catalog.format(FormatID(id)).map { WheelOption(.format($0)) }
        case .compress: WheelOption(.tool(.compress))
        case .resizeLongEdge(let edge):
            WheelOption(.tool(.compress), settings: .compressImage(goal: .level(.light), maximumLongEdge: edge))
        case .removeMetadata:
            WheelOption(.tool(.removeMetadata), settings: .removeMetadata(Set(MetadataCategory.allCases)))
        case .rename(let pattern): WheelOption(.tool(.rename), settings: .rename(pattern: pattern, start: index + 1))
        }
    }

    /// The option whose presence on a wheel shows the step fits the dragged files.
    func probe(catalog: ConversionCatalog) -> (wheel: WheelKind, option: WheelOption)? {
        switch self {
        case .convert(let id): catalog.format(FormatID(id)).map { (.convert, WheelOption(.format($0))) }
        case .compress: (.tools, WheelOption(.tool(.compress)))
        case .resizeLongEdge: (.tools, WheelOption(.tool(.resize)))
        case .removeMetadata: (.tools, WheelOption(.tool(.removeMetadata)))
        case .rename: (.tools, WheelOption(.tool(.rename)))
        }
    }
}
