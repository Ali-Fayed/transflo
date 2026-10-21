import Foundation
import os
import TransfloData
import TransfloDomain

/// Builds the tool engines that run on iPhone and iPad and the tool catalog restricted to them.
///
/// Only tools with a working native editor or a direct engine are offered.
struct MobileToolFactory {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
                                       category: "Tools")

    let engines: [any ToolEngine]
    let catalog: ToolCatalog
    private let formats: ConversionCatalog

    init(
        formats: ConversionCatalog,
        suffixes: any ToolSuffixProviding,
        nameStyle: (any ToolNameStyleProviding)? = nil,
        loader: any ToolCatalogLoading = BundledToolCatalogLoader()
    ) {
        let files = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        let naming = ToolOutputNaming(naming: files, suffixes: suffixes, style: nameStyle)
        let copier = UIPasteboardTextCopier()
        engines = [
            ImageToolEngine(ffmpeg: nil, naming: naming, copier: copier),
            PDFToolEngine(naming: naming),
            NativeVideoToolEngine(naming: naming),
            AVMediaToolEngine(naming: naming),
            FileToolEngine(naming: files, keepsOriginals: true),
            IntelligenceToolEngine(understanding: VisionImageUnderstanding(), writer: SystemLanguageModelWriter(),
                                   copier: copier, naming: naming, files: files, ffmpeg: nil)
        ]
        self.formats = formats
        do {
            let available = try loader.load().restricted(to: engines, formats: formats.formats)
            catalog = ToolCatalog(tools: available.tools.filter {
                !$0.isInteractive || MobileToolEditorModel.supported.contains($0.kind)
                    || MobileMarkupEditorFactory.tools.contains($0.kind)
            })
        } catch {
            Self.logger.fault("Tool catalog unavailable: \(String(describing: error), privacy: .public)")
            catalog = ToolCatalog(tools: [])
        }
    }

    func makeRunner() -> ToolJobRunner {
        ToolJobRunner(formats: formats, engines: engines)
    }
}
