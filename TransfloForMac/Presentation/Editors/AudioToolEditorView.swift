import SwiftUI
import TransfloDomain

struct AudioToolEditorView: View {
    @Bindable var model: AudioToolEditorViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            MediaAuditionView(url: model.item, previews: model.previews)
            if model.tool == .normalize { normalization } else {
                AppChipGroup(key: .audioChannel, selection: $model.mix, options: [
                    .init(value: .mix, label: .audioMix), .init(value: .left, label: .audioLeft),
                    .init(value: .right, label: .audioRight)
                ])
                AppText(.audioMonoHint, style: .caption, color: .secondary)
            }
            AppButton(key: .audioPreviewResult, variant: .tertiary,
                      isEnabled: model.settings != nil && !model.previewing) {
                Task { await model.prepareAudition() }
            }
            if model.previewing { AppSpinner() }
            if let data = model.currentAudition { AudioResultAuditionView(data: data) }
            if let error = model.error { SettingsFootnote(message: error, tone: .danger) }
        }
    }
    private var normalization: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                AppButton(key: .audioPodcast, variant: .tertiary) { model.preset(0) }
                AppButton(key: .audioStreaming, variant: .tertiary) { model.preset(1) }
                AppButton(key: .audioBroadcast, variant: .tertiary) { model.preset(2) }
            }
            AppDecimalNumberField(label: .audioLoudness, unit: .unitLUFS, value: $model.targets.integrated,
                                  identifier: "transflo.editor.loudness")
            AppDecimalNumberField(label: .audioPeak, unit: .unitDBTP, value: $model.targets.truePeak,
                                  identifier: "transflo.editor.peak")
            AppDecimalNumberField(label: .audioRange, unit: .unitLU, value: $model.targets.range,
                                  identifier: "transflo.editor.lra")
            if let measurement = model.measurement {
                AppText(.audioMeasured, arguments: [String(format: "%.1f", measurement.integrated),
                    String(format: "%.1f", measurement.truePeak)], style: .caption, color: .secondary)
            }
            if model.measuring { AppSpinner() }
            AppButton(key: .audioMeasure, variant: .tertiary, isEnabled: !model.measuring) {
                Task { await model.measure() }
            }
            AppText(.audioTwoPassHint, style: .caption, color: .secondary)
        }
    }
}
