import TransfloDomain

/// The Mac's Annotate or Redact editor, run unchanged on iPhone and iPad.
enum MobileMarkupEditor {
    case annotate(AnnotateEditorViewModel)
    case redact(RedactEditorViewModel)

    var model: any ToolEditorModel {
        switch self {
        case .annotate(let model): model
        case .redact(let model): model
        }
    }
}
