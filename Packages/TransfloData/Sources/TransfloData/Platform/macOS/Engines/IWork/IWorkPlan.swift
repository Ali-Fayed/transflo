#if os(macOS)
import TransfloDomain

/// How one iWork conversion runs: an optional helper conversion before, the app export,
/// and an optional helper conversion after.
struct IWorkPlan: Equatable {
    let app: IWorkApp
    let before: FormatDescriptor?
    let exportKind: String
    let after: String?

    var exportExtension: String {
        switch exportKind {
        case "png", "jpg": "images"
        default: exportKind
        }
    }

    static func make(source: String, target: String) -> IWorkPlan? {
        switch (source, target) {
        case ("pages", let target) where ["docx", "pdf", "epub", "txt"].contains(target):
            IWorkPlan(app: .pages, before: nil, exportKind: target, after: nil)
        case ("pages", let target) where ["md", "html"].contains(target):
            IWorkPlan(app: .pages, before: nil, exportKind: "docx", after: target)
        case (let source, "pages") where IWorkEngine.pagesNativeInputs.contains(source) && source != "pages":
            IWorkPlan(app: .pages, before: nil, exportKind: "pages", after: nil)
        case (let source, "pages") where ["md", "epub", "clipping", "pdf"].contains(source):
            IWorkPlan(app: .pages, before: IWorkEngine.docx, exportKind: "pages", after: nil)
        case ("pptx", let target) where ["pdf", "png", "jpg"].contains(target),
             ("ppt", let target) where ["pdf", "png", "jpg", "pptx"].contains(target):
            IWorkPlan(app: .keynote, before: nil, exportKind: target, after: nil)
        case ("xls", let target) where ["xlsx", "pdf"].contains(target):
            IWorkPlan(app: .numbers, before: nil, exportKind: target, after: nil)
        case ("xls", let target) where ["ods", "csv", "tsv"].contains(target):
            IWorkPlan(app: .numbers, before: nil, exportKind: "xlsx", after: target)
        default:
            nil
        }
    }
}
#endif
