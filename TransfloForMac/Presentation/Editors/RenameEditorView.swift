import SwiftUI
import TransfloDomain

/// Rename editor: the pattern, token shortcuts, the first number and a live preview.
struct RenameEditorView: View {
    @Bindable var model: RenameEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppTextField(label: .editorPattern, text: $model.pattern)
            HStack(spacing: AppDimensions.Spacing.small) {
                AppButton(key: .editorInsertName, variant: .tertiary) { model.insert(RenamePattern.nameToken) }
                AppButton(key: .editorInsertNumber, variant: .tertiary) { model.insert(RenamePattern.numberToken) }
                Spacer()
            }
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                AppButton(key: .editorNameThenNumber, variant: .tertiary) { model.pattern = "{name} {n}" }
                AppButton(key: .editorNumberThenName, variant: .tertiary) { model.pattern = "{n} {name}" }
                AppButton(key: .editorNumberOnly, variant: .tertiary) { model.pattern = "{n}" }
                AppButton(key: .editorReset, variant: .tertiary) {
                    model.pattern = RenameEditorViewModel.defaultPattern
                    model.start = 1
                }
            }
            AppNumberField(label: .editorStartAt, value: $model.start, range: RenameEditorViewModel.startRange)
            AppText(.editorRenameHint, style: .caption, color: .secondary)
            SettingsDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                    ForEach(model.rows) { row in
                        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                            AppText(verbatim: row.old, color: .secondary).textSelection(.enabled)
                            AppIcon(symbol: .arrowForward, size: AppDimensions.IconSize.small)
                            AppText(verbatim: row.new).textSelection(.enabled)
                        }
                    }
                    if model.hiddenCount > 0 {
                        AppText(.editorRenameMore, arguments: [String(model.hiddenCount)],
                                style: .caption, color: .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: AppDimensions.Editor.renamePreviewHeight)
        }
    }
}
