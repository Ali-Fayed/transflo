import SwiftUI
import TransfloDomain

/// Annotate and Redact in a sheet: draw on the preview with a finger or Pencil, then Apply.
struct MobileMarkupEditorView: View {
    let session: MobileWheelChoices.MarkupSession
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                editor
                    .padding(AppDimensions.Spacing.large)
                    .frame(maxWidth: AppDimensions.Mobile.readableWidth)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .appScreenBackground()
            .mobileNavigationBar(WheelPresentation.toolLabels[session.tool] ?? .wheelTools)
            .toolbar {
                MobileCloseToolbar(action: onCancel)
                ToolbarItem(placement: .confirmationAction) {
                    AppButton(key: .editorApply, variant: .primary, isEnabled: session.editor.model.settings != nil,
                              action: onApply)
                        .accessibilityIdentifier("mobile.markup.apply")
                }
            }
        }
        .interactiveDismissDisabled()
        .task { await session.editor.model.load() }
    }

    @ViewBuilder private var editor: some View {
        switch session.editor {
        case .annotate(let model): AnnotateEditorView(model: model)
        case .redact(let model): RedactEditorView(model: model)
        }
    }
}
