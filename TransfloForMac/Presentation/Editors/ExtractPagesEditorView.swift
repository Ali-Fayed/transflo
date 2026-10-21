import SwiftUI

/// Extract editor: click the pages to keep in the new PDF.
struct ExtractPagesEditorView: View {
    @Bindable var model: ExtractPagesEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppPageGrid(thumbnails: model.thumbnails, isSelected: model.isSelected, onToggle: model.toggle)
            AppTextField(label: .editorPageRanges, text: $model.rangeText)
            SettingsFootnote(message: model.rangeInvalid ? .editorPageRangeInvalid : .editorPageRangeHint,
                             tone: model.rangeInvalid ? .danger : .secondary)
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                AppButton(key: .editorApplyPageRange, variant: .tertiary) { model.applyRange() }
                AppButton(key: .editorOddPages, variant: .tertiary) { model.selectOdd() }
                AppButton(key: .editorEvenPages, variant: .tertiary) { model.selectEven() }
                AppButton(key: .editorInvertSelection, variant: .tertiary) { model.invert() }
            }
            HStack(spacing: AppDimensions.Spacing.small) {
                AppText(.editorPagesSelected, arguments: [String(model.selected.count), String(model.pageCount)],
                        style: .caption, color: .secondary)
                Spacer()
                AppButton(key: .editorSelectAll, variant: .tertiary) { model.selectAll() }
                AppButton(key: .editorSelectNone, variant: .tertiary) { model.selectNone() }
            }
        }
    }
}
