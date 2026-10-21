#if os(macOS)
import AppKit

/// Apple's free iWork apps and what Transflo asks each to do.
enum IWorkApp: String, Sendable, CaseIterable {
    case pages = "com.apple.iWork.Pages"
    case keynote = "com.apple.iWork.Keynote"
    case numbers = "com.apple.iWork.Numbers"

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil
    }

    /// Script run with `osascript`: argv is input path, output path, export kind. Paths are never
    /// spliced into the source, so a crafted file name cannot change what the script does.
    var script: [String] {
        let exports: [(String, String)] = switch self {
        case .pages:
            [("docx", "export theDoc to outputFile as Microsoft Word"), ("pdf", "export theDoc to outputFile as PDF"),
             ("epub", "export theDoc to outputFile as EPUB"),
             ("txt", "export theDoc to outputFile as unformatted text"), ("pages", "save theDoc in outputFile")]
        case .keynote:
            [("pdf", "export theDoc to outputFile as PDF"),
             ("pptx", "export theDoc to outputFile as Microsoft PowerPoint"),
             ("png", "export theDoc to outputFile as slide images with properties {image format:PNG}"),
             ("jpg", "export theDoc to outputFile as slide images with properties {image format:JPEG}")]
        case .numbers:
            [("xlsx", "export theDoc to outputFile as Microsoft Excel"), ("pdf", "export theDoc to outputFile as PDF")]
        }
        let branches = exports.enumerated().flatMap { index, export in
            ["\(index == 0 ? "if" : "else if") exportKind is \"\(export.0)\" then", export.1]
        }
        return [
            "on run argv",
            "set inputFile to POSIX file (item 1 of argv)",
            "set outputFile to POSIX file (item 2 of argv)",
            "set exportKind to item 3 of argv",
            "tell application id \"\(rawValue)\"",
            "set theDoc to open inputFile",
            "try"
        ] + branches + [
            "else",
            "error \"unsupported export\" number 1",
            "end if",
            "close theDoc saving no",
            "on error errorText number errorNumber",
            "close theDoc saving no",
            "error errorText number errorNumber",
            "end try",
            "end tell",
            "end run"
        ]
    }

    /// The export kinds the script supports.
    var exportKinds: Set<String> {
        switch self {
        case .pages: ["docx", "pdf", "epub", "txt", "pages"]
        case .keynote: ["pdf", "pptx", "png", "jpg"]
        case .numbers: ["xlsx", "pdf"]
        }
    }
}
#endif
