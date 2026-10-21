import SwiftUI

/// Trim editor: a two-handle range over the clip's length.
struct TrimEditorView: View {
    @Bindable var model: TrimEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            MediaAuditionView(url: model.item, start: model.start, end: model.end, previews: model.previews)
            if model.preview.thumbnail != nil {
                AppPreviewImage(data: model.preview.thumbnail).frame(height: AppDimensions.Editor.previewHeight)
            }
            AppRangeSlider(lower: $model.start, upper: $model.end, bounds: 0...max(model.duration, 0.1),
                           minimumSpan: TrimEditorViewModel.minimumLength)
            AppTimeRangeFields(start: $model.start, end: $model.end)
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                AppButton(key: .editorFirstHalf, variant: .tertiary) { model.selectFraction(0, 0.5) }
                AppButton(key: .editorMiddleHalf, variant: .tertiary) { model.selectFraction(0.25, 0.75) }
                AppButton(key: .editorLastHalf, variant: .tertiary) { model.selectFraction(0.5, 1) }
                AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
            }
            AppText(.editorRange, arguments: [
                TimeLabel.text(model.start), TimeLabel.text(model.end), TimeLabel.text(model.end - model.start)
            ], style: .caption, color: .secondary)
        }
    }
}
