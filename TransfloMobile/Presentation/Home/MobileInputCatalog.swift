import Foundation
import TransfloDomain
import UniformTypeIdentifiers

/// Picker categories come from runnable mobile conversion sources and tool inputs.
/// Archives and output-only formats are excluded.
struct MobileInputCatalog {
    enum Kind: String, CaseIterable, Identifiable {
        case image, pdf, audio, video, subtitle, text, document
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .image: "photo"
            case .pdf: "doc.richtext"
            case .audio: "waveform"
            case .video: "film"
            case .subtitle: "captions.bubble"
            case .text, .document: "doc.text"
            }
        }
        var title: L10nKey {
            switch self {
            case .image: .mobileSelectImage
            case .pdf: .mobileSelectPDF
            case .audio: .mobileSelectAudio
            case .video: .mobileSelectVideo
            case .subtitle: .mobileSelectSubtitle
            case .text: .mobileSelectText
            case .document: .mobileSelectDocument
            }
        }
    }

    struct Option: Identifiable {
        let kind: Kind
        let extensions: Set<String>
        let contentTypes: [UTType]
        var id: Kind { kind }
    }

    let options: [Option]
    private let extensions: Set<String>

    init(catalog: ConversionCatalog, tools: ToolCatalog? = nil) {
        let sources = Set(catalog.paths.map(\.source))
        let formats = catalog.formats.filter { format in
            guard Self.kind(for: format) != nil else { return false }
            return sources.contains(format.id) || tools?.tools.contains { tool in
                !tool.appliesToAnyFile && !tool.requiresMultipleFiles && tool.accepts(format)
            } == true
        }
        extensions = Set(formats.flatMap(\.extensions))
        options = Kind.allCases.compactMap { kind in
            let selected = formats.filter { Self.kind(for: $0) == kind }
            let extensions = Set(selected.flatMap(\.extensions))
            // Declared types only: an undeclared extension maps to a dynamic type no file conforms to.
            let types = extensions.sorted().compactMap { UTType(filenameExtension: $0, conformingTo: .data) }
                .filter { !$0.isDynamic }
            guard !types.isEmpty else { return nil }
            return Option(kind: kind, extensions: extensions, contentTypes: types)
        }
    }

    func accepts(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { extensions.contains($0.pathExtension.lowercased()) }
    }

    /// The Home category for `format`; archives have none on iPhone and iPad.
    private static func kind(for format: FormatDescriptor) -> Kind? {
        switch format.family {
        case .image: .image
        case .audio: .audio
        case .video: .video
        case .subtitle: .subtitle
        case .archive: nil
        case .document where format.extensions.contains("pdf"): .pdf
        case .document where format.extensions.contains("txt"): .text
        case .document, .presentation, .spreadsheet: .document
        }
    }
}
