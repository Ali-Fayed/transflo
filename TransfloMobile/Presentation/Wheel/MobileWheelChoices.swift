import Foundation
import Observation
import TransfloDomain

/// Editors close before scheduling, so a fast result never races the editor's sheet dismissal.
@Observable
final class MobileWheelChoices: ToolEditing, ActionPreparing {
    struct Session: Identifiable {
        let id = UUID()
        let model: MobileToolEditorModel
        let onApply: (ToolSettings) -> Void
    }
    struct MarkupSession: Identifiable {
        let id = UUID()
        let tool: ToolKind
        let editor: MobileMarkupEditor
        let onApply: (ToolSettings) -> Void
    }
    var session: Session?
    var markup: MarkupSession?
    private(set) var isPresented = false
    @ObservationIgnored private var pendingApply: (() -> Void)?
    @ObservationIgnored private let compressionGoal: () -> CompressionGoal
    @ObservationIgnored private let markupEditors: any MobileMarkupEditorMaking

    init(markupEditors: any MobileMarkupEditorMaking, compressionGoal: @escaping () -> CompressionGoal = { .medium }) {
        self.markupEditors = markupEditors
        self.compressionGoal = compressionGoal
    }

    func canEdit(_ tool: ToolKind) -> Bool {
        MobileToolEditorModel.supported.contains(tool) || MobileMarkupEditorFactory.tools.contains(tool)
    }

    func edit(_ tool: ToolKind, items: [URL], onApply: @escaping (ToolSettings) -> Void) {
        guard canEdit(tool), let first = items.first else { return }
        if MobileMarkupEditorFactory.tools.contains(tool) {
            guard let editor = markupEditors.editor(for: tool, item: first) else { return }
            isPresented = true
            markup = MarkupSession(tool: tool, editor: editor, onApply: onApply)
            return
        }
        isPresented = true
        let model = MobileToolEditorModel(tool: tool, items: items)
        switch CompressionChoice(compressionGoal()) {
        case .light: model.compression = 0
        case .medium: model.compression = 1
        case .strong: model.compression = 2
        }
        session = Session(model: model, onApply: onApply)
    }

    func apply() {
        guard let session, session.model.isValid else { return }
        let settings = session.model.settings
        pendingApply = { session.onApply(settings) }
        self.session = nil
    }

    /// Runs the markup editor's marks; does nothing until there is at least one.
    func applyMarkup() {
        guard let markup, let settings = markup.editor.model.settings else { return }
        pendingApply = { markup.onApply(settings) }
        self.markup = nil
    }

    func cancel() {
        session = nil
        markup = nil
    }

    func didDismiss() {
        isPresented = false
        let apply = pendingApply
        pendingApply = nil
        apply?()
    }

    func needsPreparation(_ action: ActionKind) -> Bool { false }
    func prepare(
        _ action: ActionKind, items: [URL], near point: WheelPoint, onReady: @escaping (ToolSettings) -> Void
    ) {}
}
