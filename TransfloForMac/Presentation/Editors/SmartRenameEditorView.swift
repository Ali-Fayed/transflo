import SwiftUI

/// Smart Rename editor: one editable suggested name per file, with the resulting file name.
struct SmartRenameEditorView: View {
    @Bindable var model: SmartRenameEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.smartRenameHint, style: .caption, color: .secondary)
            if model.isSuggesting {
                HStack(spacing: AppDimensions.Spacing.small) {
                    AppSpinner()
                    AppText(.smartRenameSuggesting, color: .secondary)
                }
            }
            if let error = model.error { SettingsFootnote(message: error, tone: .danger) }
            ScrollView {
                VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
                    ForEach(model.names.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                            AppTextField(content: .verbatim(model.items[index].lastPathComponent),
                                         text: $model.names[index])
                            AppText(verbatim: model.preview(at: index), style: .caption, color: .secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: AppDimensions.Editor.renamePreviewHeight)
        }
        .accessibilityIdentifier("editor.smartRename")
    }
}
