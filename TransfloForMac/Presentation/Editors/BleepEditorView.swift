import SwiftUI

/// Bleep editor: select a stretch, add it, repeat; the list shows what will be covered.
struct BleepEditorView: View {
    @Bindable var model: BleepEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            MediaAuditionView(url: model.item, start: model.start, end: model.end, previews: model.previews)
            if model.preview.thumbnail != nil {
                AppPreviewImage(data: model.preview.thumbnail).frame(height: AppDimensions.Editor.previewHeight / 2)
            }
            AppRangeSlider(lower: $model.start, upper: $model.end, bounds: 0...max(model.duration, 0.1),
                           minimumSpan: BleepEditorViewModel.minimumLength)
            AppTimeRangeFields(start: $model.start, end: $model.end)
            HStack {
                AppText(.editorRange, arguments: [
                    TimeLabel.text(model.start), TimeLabel.text(model.end), TimeLabel.text(model.end - model.start)
                ], style: .caption, color: .secondary)
                Spacer()
                AppButton(key: .editorAddBleep, variant: .tertiary, isEnabled: model.canAdd) { model.addSpan() }
            }
            HStack {
                AppButton(key: .editorNextInterval, variant: .tertiary,
                          isEnabled: model.end < model.duration) { model.nextSelection() }
                AppButton(key: .editorClear, variant: .tertiary, isEnabled: !model.spans.isEmpty) { model.clear() }
            }
            SettingsFootnote(message: .editorBleepToneHint)
            SettingsDivider()
            AppText(.editorBleeps, style: .headline)
            if model.spans.isEmpty {
                AppText(.editorNoBleeps, style: .caption, color: .secondary)
            }
            ForEach(model.spans, id: \.self) { span in
                HStack {
                    AppText(verbatim: "\(TimeLabel.text(span.start)) – \(TimeLabel.text(span.end))")
                    Spacer()
                    AppIconButton(symbol: .remove, label: .editorRemove) { model.remove(span) }
                }
            }
        }
    }
}
