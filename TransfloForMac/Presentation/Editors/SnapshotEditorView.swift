import SwiftUI

/// Snapshot editor: scrub to a moment and see that frame.
struct SnapshotEditorView: View {
    @Bindable var model: SnapshotEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            HStack {
                AppButton(key: .snapshotPrevious, variant: .tertiary) { model.stepFrame(-1) }
                AppButton(key: .snapshotNext, variant: .tertiary) { model.stepFrame(1) }
            }
            SettingsRow(label: .snapshotJPEG) { AppToggle(key: .snapshotJPEG, isOn: $model.jpeg) }
            if model.jpeg {
                AppNumberField(label: .compressionQuality, value: $model.quality, range: 1...100, unit: .unitPercent)
            }
            MediaAuditionView(url: model.item, previews: model.previews)
            AppPreviewImage(data: model.frame).frame(height: AppDimensions.Editor.previewHeight)
            AppSlider(label: .editorFrameAt, value: $model.time, range: 0...max(model.maximumTime, 0.001),
                      valueText: TimeLabel.text(model.time))
            AppDecimalNumberField(label: .editorFrameAt, unit: .unitSeconds, value: $model.time,
                                  identifier: "transflo.snapshot.time", precision: 3)
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                ForEach([0.0, 0.25, 0.5, 0.75, 1], id: \.self) { fraction in
                    AppButton(label: .verbatim(fraction.formatted(.percent)), variant: .tertiary) {
                        model.selectFraction(fraction)
                    }
                }
            }
            SettingsFootnote(message: .editorSnapshotHint)
        }
        .task(id: model.time) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await model.refreshFrame()
        }
    }
}
