import SwiftUI

struct RotateEditorView: View {
    @Bindable var model: RotateEditorViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            GeometryReader { proxy in
                let odd = !model.quarterTurns.isMultiple(of: 2)
                let originalAspect = PreviewAspect.ratio(model.preview)
                let aspect = odd ? 1 / originalAspect : originalAspect
                let outputWidth = min(proxy.size.width, proxy.size.height * aspect)
                let outputHeight = outputWidth / aspect
                AppPreviewImage(data: model.preview.thumbnail, backdrop: .clear)
                    .frame(width: odd ? outputHeight : outputWidth, height: odd ? outputWidth : outputHeight)
                    .rotationEffect(.degrees(Double(model.quarterTurns) * 90))
                    .scaleEffect(x: model.flipHorizontal ? -1 : 1, y: model.flipVertical ? -1 : 1)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .frame(height: AppDimensions.Editor.previewHeight)
            .clipped()
            if model.supportsMirroring, let size = model.outputSize {
                AppText(.editorOutputSize, arguments: [String(size.width), String(size.height)],
                        style: .caption, color: .secondary)
            }
            AppChipGroup(key: .toolRotate, selection: $model.quarterTurns, options: [
                .init(value: 0, label: .editorNoRotation), .init(value: 1, label: .editorRotate90),
                .init(value: 2, label: .editorRotate180), .init(value: 3, label: .editorRotate270)
            ])
            if model.supportsMirroring {
                SettingsRow(label: .editorFlipHorizontal) {
                    AppToggle(key: .editorFlipHorizontal, isOn: $model.flipHorizontal)
                }
                SettingsRow(label: .editorFlipVertical) {
                    AppToggle(key: .editorFlipVertical, isOn: $model.flipVertical)
                }
            }
            AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
        }
    }
}
