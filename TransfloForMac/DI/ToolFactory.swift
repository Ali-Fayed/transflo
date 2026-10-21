import Foundation
import os
import TransfloData
import TransfloDomain
import TransfloSystem

/// Builds the tool engines and the tool catalog restricted to what they can run.
struct ToolFactory {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "Tools"
    )

    let engines: [any ToolEngine]
    let catalog: ToolCatalog
    let previews: any ToolPreviewProviding
    let inspector: any ToolInspectionProviding
    let metadata: any ToolMetadataReading
    /// Smart Rename's suggestions, shared by its engine and its editor.
    let nameSuggester: SuggestFileNamesUseCase
    private let formats: ConversionCatalog

    init(
        formats: ConversionCatalog,
        suffixes: any ToolSuffixProviding,
        loader: any ToolCatalogLoading = BundledToolCatalogLoader(),
        bundle: Bundle = .main,
        nameStyle: (any ToolNameStyleProviding)? = nil
    ) {
        let files = NameOutputFileUseCase(checker: FileManagerExistenceChecker())
        let naming = ToolOutputNaming(naming: files, suffixes: suffixes, style: nameStyle)
        let ffmpeg = FFmpegEngine.bundledBinary(in: bundle)
        let ffprobe = FFmpegEngine.bundledProbe(in: bundle)
        previews = MediaToolPreviewProvider(ffmpeg: ffmpeg, ffprobe: ffprobe)
        metadata = FileMetadataReader(ffprobe: ffprobe)
        inspector = ToolInspector(formats: formats, ffmpeg: ffmpeg, ffprobe: ffprobe)
        let understanding = VisionImageUnderstanding()
        let writer = SystemLanguageModelWriter()
        nameSuggester = SuggestFileNamesUseCase(understanding: understanding, writer: writer)
        engines = [
            ImageToolEngine(ffmpeg: ffmpeg, naming: naming, copier: PasteboardTextCopier()),
            MediaToolEngine(ffmpeg: ffmpeg, ffprobe: ffprobe, naming: naming),
            GIFCompressionEngine(ffmpeg: ffmpeg, naming: naming),
            PDFToolEngine(naming: naming),
            FileToolEngine(naming: files),
            ArchiveExtractionEngine(naming: files),
            IntelligenceToolEngine(understanding: understanding, writer: writer, copier: PasteboardTextCopier(),
                                   naming: naming, files: files, ffmpeg: ffmpeg)
        ]
        self.formats = formats
        do {
            catalog = try loader.load().restricted(to: engines, formats: formats.formats)
        } catch {
            Self.logger.fault("Tool catalog unavailable: \(String(describing: error), privacy: .public)")
            catalog = ToolCatalog(tools: [])
        }
    }

    func makeEditors(
        formats: ConversionCatalog, localizer: Localizer, preferences: any ToolPreferencesRepository
    ) -> ToolEditorCoordinator {
        ToolEditorCoordinator(formats: formats, previews: previews, metadata: metadata, localizer: localizer,
                              backgroundRenderer: BackgroundPreviewRenderer(),
                              compressionGoal: { preferences.loadCompressionGoal() }, inspector: inspector,
                              nameSuggester: nameSuggester)
    }

    func makeRunner() -> ToolJobRunner {
        ToolJobRunner(formats: formats, engines: engines)
    }
}
