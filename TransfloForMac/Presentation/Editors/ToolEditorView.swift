import SwiftUI
import TransfloDomain

/// Hosts the right editor for a session inside the shared scaffold.
struct ToolEditorView: View {
    let tool: ToolKind
    let session: ToolEditorSession
    var itemCount = 1
    @State private var didLoad = false
    let onCancel: () -> Void
    let onApply: (ToolSettings) -> Void
    var validate: ((ToolSettings) async throws -> Void)?
    @State private var validating = false
    @State private var validationTask: Task<Void, Never>?
    @State private var validationError: L10nKey?

    var body: some View {
        AppEditorScaffold(
            title: WheelPresentation.toolLabels[tool] ?? .wheelTools,
            canApply: !validating && didLoad && !session.previewUnavailable && session.model.settings != nil,
            onCancel: { validationTask?.cancel(); onCancel() },
            onApply: apply,
            actionKey: actionKey,
            width: tool == .addBackground ? AppDimensions.Beautify.editorWidth : AppDimensions.Editor.width,
            content: {
                VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
                    if validating { AppSpinner() }
                    if let validationError { SettingsFootnote(message: validationError, tone: .danger) }
                    if itemCount > 1 && ![.compress, .collage, .rename, .merge, .imagesToPDF,
                                         .readCode, .removeMetadata, .smartRename].contains(tool) {
                        AppText(.editorBatchHint, arguments: [String(itemCount)], style: .caption, color: .secondary)
                    }
                    if didLoad && session.previewUnavailable {
                        SettingsFootnote(message: .editorPreviewUnavailable, tone: .danger)
                        AppButton(key: .beautifyRetry, variant: .tertiary) {
                            Task { didLoad = false; await session.model.load(); didLoad = true }
                        }
                    }
                    editor
                }
            }
        )
        .task { await session.model.load(); didLoad = !Task.isCancelled }
        .onDisappear { validationTask?.cancel() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(didLoad ? "transflo.editor.ready" : "transflo.editor.loading")
    }

    private func apply() {
        guard let settings = session.model.settings, !validating else { return }
        validating = true; validationError = nil
        validationTask = Task {
            defer { validating = false }
            do {
                try await validate?(settings)
                guard !Task.isCancelled else { return }
                onApply(settings)
            } catch {
                validationError = (error as? JobError).map(JobPresentation.message(for:)) ?? .errorFailed
            }
        }
    }

    private var actionKey: L10nKey {
        switch tool {
        case .addBackground: .beautifySave
        case .adjust: .editorSaveEditedCopy
        case .compress: .toolCompress
        case .readCode: .codesCopySelected
        default: WheelPresentation.toolLabels[tool] ?? .editorApply
        }
    }

    @ViewBuilder private var editor: some View {
        switch session {
        case .assembly(let model): AssemblyEditorView(model: model)
        case .backgroundRemoval(let model): BackgroundRemovalEditorView(model: model)
        case .audio(let model): AudioToolEditorView(model: model)
        case .codes(let model): CodeResultsView(model: model)
        case .removeMetadata(let model): MetadataRemovalEditorView(model: model)
        case .rotate(let model): RotateEditorView(model: model)
        case .compress(let model): CompressEditorView(model: model)
        case .resize(let model): ResizeEditorView(model: model)
        case .crop(let model): CropEditorView(model: model)
        case .adjust(let model): AdjustEditorView(model: model)
        case .trim(let model): TrimEditorView(model: model)
        case .speed(let model): SpeedEditorView(model: model)
        case .split(let model): SplitEditorView(model: model)
        case .snapshot(let model): SnapshotEditorView(model: model)
        case .annotate(let model): AnnotateEditorView(model: model)
        case .redact(let model): RedactEditorView(model: model)
        case .background(let model): AddBackgroundEditorView(model: model)
        case .collage(let model): CollageEditorView(model: model)
        case .bleep(let model): BleepEditorView(model: model)
        case .reorganize(let model): ReorganizePagesEditorView(model: model)
        case .extract(let model): ExtractPagesEditorView(model: model)
        case .metadata(let model): MetadataEditorView(model: model)
        case .rename(let model): RenameEditorView(model: model)
        case .smartRename(let model): SmartRenameEditorView(model: model)
        }
    }
}
