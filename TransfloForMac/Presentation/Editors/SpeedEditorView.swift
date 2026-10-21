import SwiftUI
import TransfloDomain

/// Change-speed editor: a rate slider and the resulting length.
struct SpeedEditorView: View {
    @Bindable var model: SpeedEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            MediaAuditionView(url: model.item, rate: model.factor, previews: model.previews)
            AppSlider(label: .editorSpeed, value: $model.factor, range: ToolSettings.speedRange,
                      valueText: model.factor.formatted(.number.precision(.fractionLength(2))) + "×")
            AppDecimalNumberField(label: .editorExactSpeed, unit: .unitMultiplier, value: $model.factor,
                                  identifier: "transflo.speed.factor")
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                ForEach([0.25, 0.5, 0.75, 1.25, 1.5, 2, 4], id: \.self) { factor in
                    AppButton(label: .formatted(.editorSpeedValue, [factor.formatted()]), variant: .tertiary) {
                        model.factor = factor
                    }
                }
                AppButton(key: .editorReset, variant: .tertiary) { model.factor = 1 }
            }
            if let length = model.newDuration {
                AppText(.editorNewLength, arguments: [TimeLabel.text(length)], style: .caption, color: .secondary)
            }
        }
    }
}
