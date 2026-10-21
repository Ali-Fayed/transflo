import SwiftUI

/// Edit metadata editor: title, author and comment fields.
struct MetadataEditorView: View {
    @Bindable var model: MetadataEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(verbatim: model.fileName, style: .caption, color: .secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                AppTextField(label: .metadataTitle, text: $model.title)
                AppIconButton(symbol: .remove, label: .editorClear) { model.title = "" }
            }
            HStack {
                AppTextField(label: .metadataAuthor, text: $model.author)
                AppIconButton(symbol: .remove, label: .editorClear) { model.author = "" }
            }
            AppText(.metadataComment)
            AppTextEditor(label: .metadataComment, text: $model.comment)
                .accessibilityIdentifier("transflo.metadata.comment")
            HStack {
                AppButton(key: .editorRestoreOriginal, variant: .tertiary) { model.restore() }
                AppButton(key: .editorClear, variant: .tertiary) { model.clear() }
            }
            AppText(.editorMetadataHint, style: .caption, color: .secondary)
            AppDisclosure(label: .key(.metadataInspectFields)) {
                ForEach(model.detected, id: \.self) { entry in
                    AppMetadataEntry(name: entry.name, value: entry.value)
                }
            }
        }
    }
}
