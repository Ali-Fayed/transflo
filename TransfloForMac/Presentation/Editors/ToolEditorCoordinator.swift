import AppKit
import SwiftUI
import TransfloDomain

/// Opens tool editors in their own window (Coordinator pattern); Apply hands back settings.
final class ToolEditorCoordinator: ToolEditing {
    static let editableTools: Set<ToolKind> = [
        .compress, .rotate, .resize, .crop, .adjust, .trim, .changeSpeed, .split, .snapshot,
        .annotate, .redact, .addBackground,
        .collage, .bleep, .reorganizePages, .extractPages, .editMetadata, .rename,
        .merge, .imagesToPDF, .removeBackground, .normalize, .channels, .readCode, .removeMetadata,
        .smartRename
    ]

    private let inspector: (any ToolInspectionProviding)?
    private let nameSuggester: SuggestFileNamesUseCase?
    private let formats: ConversionCatalog
    private let previews: any ToolPreviewProviding
    private let metadata: any ToolMetadataReading
    private let backgroundRenderer: (any BackgroundPreviewRendering)?
    private let localizer: Localizer
    private let compressionGoal: () -> CompressionGoal
    private var window: NSWindow?

    init(
        formats: ConversionCatalog,
        previews: any ToolPreviewProviding,
        metadata: any ToolMetadataReading,
        localizer: Localizer,
        backgroundRenderer: (any BackgroundPreviewRendering)? = nil,
        compressionGoal: @escaping () -> CompressionGoal = { .medium },
        inspector: (any ToolInspectionProviding)? = nil,
        nameSuggester: SuggestFileNamesUseCase? = nil
    ) {
        self.inspector = inspector
        self.nameSuggester = nameSuggester
        self.compressionGoal = compressionGoal
        self.formats = formats
        self.previews = previews
        self.metadata = metadata
        self.localizer = localizer
        self.backgroundRenderer = backgroundRenderer
    }

    func canEdit(_ tool: ToolKind) -> Bool {
        Self.editableTools.contains(tool)
    }

    func edit(_ tool: ToolKind, items: [URL], onApply: @escaping (ToolSettings) -> Void) {
        guard let session = makeSession(tool, items: items) else { return }
        window?.close()
        let inspection = inspector
        let root = AppLocalizedRoot(localizer: localizer) { [weak self] in
            ToolEditorView(
                tool: tool,
                session: session,
                itemCount: items.count,
                onCancel: { self?.close() },
                onApply: { settings in
                    self?.close()
                    onApply(settings)
                },
                validate: { settings in
                    try await inspection?.validate(settings, tool: tool, items: items)
                }
            )
        }
        let window = AppWindow.make(
            contentViewController: NSHostingController(rootView: root), identifier: WindowIdentifier.toolEditor
        )
        window.title = localizer.string(WheelPresentation.toolLabels[tool] ?? .wheelTools)
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// The typed session for `tool`, or `nil` if the tool has no editor or there are no files.
    func makeSession(_ tool: ToolKind, items: [URL]) -> ToolEditorSession? {
        guard let item = items.first else { return nil }
        let format = formats.format(forFileExtension: item.pathExtension)
        return makeInspectionSession(tool, item: item, items: items, format: format)
            ?? makeCoreSession(tool, item: item, items: items, format: format)
    }

    private func makeCoreSession(_ tool: ToolKind, item: URL, items: [URL], format: FormatDescriptor?)
        -> ToolEditorSession? {
        switch tool {
        case .compress:
            return .compress(CompressEditorViewModel(items: items, formats: items.map {
                formats.format(forFileExtension: $0.pathExtension)
            }, initialGoal: compressionGoal()))
        case .resize: return .resize(ResizeEditorViewModel(item: item, format: format, previews: previews))
        case .crop: return .crop(CropEditorViewModel(item: item, format: format, previews: previews))
        case .adjust: return .adjust(AdjustEditorViewModel(item: item, format: format, previews: previews))
        case .trim: return .trim(TrimEditorViewModel(item: item, format: format, previews: previews))
        case .changeSpeed: return .speed(SpeedEditorViewModel(item: item, format: format, previews: previews))
        case .split: return .split(SplitEditorViewModel(item: item, format: format, previews: previews))
        case .snapshot: return .snapshot(SnapshotEditorViewModel(item: item, format: format, previews: previews))
        default:
            return makeMarkupSession(tool, item: item, items: items, format: format)
                ?? makePageOrFileSession(tool, item: item, items: items, format: format)
        }
    }

    private func makeInspectionSession(_ tool: ToolKind, item: URL, items: [URL], format: FormatDescriptor?)
        -> ToolEditorSession? {
        switch tool {
        case .merge, .imagesToPDF:
            return .assembly(AssemblyEditorViewModel(items: items, formats: items.map {
                formats.format(forFileExtension: $0.pathExtension)
            }, isPDFExport: tool == .imagesToPDF, previews: previews))
        case .removeBackground:
            return .backgroundRemoval(BackgroundRemovalEditorViewModel(item: item, format: format,
                previews: previews, inspector: inspector))
        case .normalize, .channels:
            return .audio(AudioToolEditorViewModel(item: item, format: format, tool: tool,
                                                  previews: previews, inspector: inspector))
        case .readCode: return .codes(CodeResultsViewModel(items: items, inspector: inspector))
        case .removeMetadata: return .removeMetadata(MetadataRemovalEditorViewModel(items: items, inspector: inspector))
        default: return nil
        }
    }

    private func makeMarkupSession(_ tool: ToolKind, item: URL, items: [URL], format: FormatDescriptor?)
        -> ToolEditorSession? {
        switch tool {
        case .rotate: return .rotate(RotateEditorViewModel(item: item, format: format, previews: previews))
        case .annotate: return .annotate(AnnotateEditorViewModel(item: item, format: format, previews: previews))
        case .redact: return .redact(RedactEditorViewModel(item: item, format: format, previews: previews))
        case .addBackground:
            return .background(AddBackgroundEditorViewModel(item: item, format: format, previews: previews,
                                                           renderer: backgroundRenderer, initialStyle: .beautified))
        case .collage:
            let itemFormats = items.map { formats.format(forFileExtension: $0.pathExtension) }
            return .collage(CollageEditorViewModel(items: items, formats: itemFormats,
                                                  previews: previews, inspector: inspector))
        default: return nil
        }
    }

    private func makePageOrFileSession(_ tool: ToolKind, item: URL, items: [URL], format: FormatDescriptor?)
        -> ToolEditorSession? {
        switch tool {
        case .bleep: return .bleep(BleepEditorViewModel(item: item, format: format, previews: previews))
        case .reorganizePages: return .reorganize(ReorganizePagesEditorViewModel(item: item, previews: previews))
        case .extractPages: return .extract(ExtractPagesEditorViewModel(item: item, previews: previews))
        case .editMetadata:
            return .metadata(MetadataEditorViewModel(item: item, format: format,
                                                     reader: metadata, inspector: inspector))
        case .rename: return .rename(RenameEditorViewModel(items: items))
        case .smartRename:
            return .smartRename(SmartRenameEditorViewModel(items: items, suggester: nameSuggester))
        default: return nil
        }
    }

    private func close() {
        window?.close()
        window = nil
    }
}
