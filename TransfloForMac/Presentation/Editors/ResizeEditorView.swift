import SwiftUI

/// Resize editor: preview, width and height fields, proportion lock and quick sizes.
struct ResizeEditorView: View {
    @Bindable var model: ResizeEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppPreviewImage(data: model.preview.thumbnail).frame(height: AppDimensions.Editor.previewHeight)
            if let width = model.preview.width, let height = model.preview.height {
                AppText(.editorOriginalSize, arguments: [String(width), String(height)],
                        style: .caption, color: .secondary)
            }
            AppNumberField(label: .editorWidth, value: widthBinding, range: ResizeEditorViewModel.sizeRange)
            AppNumberField(label: .editorHeight, value: heightBinding, range: ResizeEditorViewModel.sizeRange)
            SettingsRow(label: .editorKeepProportions) {
                AppToggle(key: .editorKeepProportions, isOn: $model.keepsProportions)
            }
            HStack(spacing: AppDimensions.Spacing.small) {
                AppButton(key: .editorHalfSize, variant: .tertiary) { model.scale(50) }
                AppButton(key: .editorQuarterSize, variant: .tertiary) { model.scale(25) }
            }
            AppNumberField(label: .editorScalePercentage, value: $model.percentage, range: 1...400, unit: .unitPercent)
            AppButton(key: .editorApplyScale, variant: .tertiary) { model.applyPercentage() }
            AppText(.editorFitLongEdge, style: .headline)
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                ForEach([1280, 1920, 2560], id: \.self) { edge in
                    AppButton(label: .formatted(.editorPixelsValue, [String(edge)]), variant: .tertiary) {
                        model.fitLongEdge(edge)
                    }
                }
            }
            AppText(.editorActualPixels, arguments: [String(model.outputWidth), String(model.outputHeight)],
                    style: .caption, color: .secondary)
            if model.enlarges { SettingsFootnote(message: .editorEnlargeHint) }
            AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
        }
    }

    private var widthBinding: Binding<Int> {
        Binding(get: { model.width }, set: { model.setWidth($0) })
    }

    private var heightBinding: Binding<Int> {
        Binding(get: { model.height }, set: { model.setHeight($0) })
    }
}
