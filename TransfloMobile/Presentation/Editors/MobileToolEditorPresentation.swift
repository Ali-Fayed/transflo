import SwiftUI

/// Presents whichever tool editor the wheel opened: the form editors or the markup board.
private struct MobileToolEditorPresentation: ViewModifier {
    let choices: MobileWheelChoices

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding(get: { choices.session }, set: { choices.session = $0 }),
                   onDismiss: choices.didDismiss) { session in
                MobileToolEditorView(model: session.model, onCancel: choices.cancel, onApply: choices.apply)
            }
            .sheet(item: Binding(get: { choices.markup }, set: { choices.markup = $0 }),
                   onDismiss: choices.didDismiss) { session in
                MobileMarkupEditorView(session: session, onCancel: choices.cancel, onApply: choices.applyMarkup)
                    .presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
            }
    }
}

extension View {
    /// Shows the wheel's tool editors as sheets.
    func toolEditors(_ choices: MobileWheelChoices) -> some View {
        modifier(MobileToolEditorPresentation(choices: choices))
    }
}
