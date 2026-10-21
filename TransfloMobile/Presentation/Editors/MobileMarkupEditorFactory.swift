import Foundation
import TransfloDomain

/// Factory for the markup editors: each gets the file's format and the still-preview provider.
struct MobileMarkupEditorFactory: MobileMarkupEditorMaking {
    static let tools: Set<ToolKind> = [.annotate, .redact]

    let formats: ConversionCatalog
    let previews: any ToolPreviewProviding

    func editor(for tool: ToolKind, item: URL) -> MobileMarkupEditor? {
        let format = formats.format(forFileExtension: item.pathExtension)
        switch tool {
        case .annotate: return .annotate(AnnotateEditorViewModel(item: item, format: format, previews: previews))
        case .redact: return .redact(RedactEditorViewModel(item: item, format: format, previews: previews))
        default: return nil
        }
    }
}
