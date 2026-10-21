import SwiftUI

/// Crop editor: the crop box over the preview and shape presets.
struct CropEditorView: View {
    @Bindable var model: CropEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppPreviewImage(data: model.preview.thumbnail)
                .overlay {
                    if model.preview.thumbnail != nil {
                        AppCropOverlay(rect: model.rect, onChange: { proposal, _ in model.propose(proposal) },
                                       showsGrid: model.showsGrid)
                    }
                }
                .modifier(AppPreviewFrame(aspectRatio: PreviewAspect.ratio(model.preview)))
            AppChipGroup(key: .editorAspect, selection: aspectBinding, options: Self.aspects)
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
                AppNumberField(label: .editorWidth,
                               value: Binding(get: { model.pixelWidth }, set: { model.setWidth($0) }),
                               range: 1...model.maximumWidth, unit: .unitPixels, rejectsBelowMinimum: true)
                AppNumberField(label: .editorHeight,
                               value: Binding(get: { model.pixelHeight }, set: { model.setHeight($0) }),
                               range: 1...model.maximumHeight, unit: .unitPixels, rejectsBelowMinimum: true)
            }
            AppNumberField(label: .editorCropX,
                           value: Binding(get: { model.pixelX }, set: { model.setPosition(x: $0, y: model.pixelY) }),
                           range: 0...model.maximumWidth, unit: .unitPixels)
            AppNumberField(label: .editorCropY,
                           value: Binding(get: { model.pixelY }, set: { model.setPosition(x: model.pixelX, y: $0) }),
                           range: 0...model.maximumHeight, unit: .unitPixels)
            SettingsRow(label: .editorCropGrid) { AppToggle(key: .editorCropGrid, isOn: $model.showsGrid) }
            HStack {
                AppButton(key: .editorNudgeLeft, variant: .tertiary) { model.nudge(x: -1, y: 0) }
                AppButton(key: .editorNudgeRight, variant: .tertiary) { model.nudge(x: 1, y: 0) }
                AppButton(key: .editorNudgeUp, variant: .tertiary) { model.nudge(x: 0, y: -1) }
                AppButton(key: .editorNudgeDown, variant: .tertiary) { model.nudge(x: 0, y: 1) }
            }
            AppText(.editorActualPixels,
                    arguments: [String(model.outputPixels.width), String(model.outputPixels.height)],
                    style: .caption, color: .secondary)
            HStack {
                AppButton(key: .editorCenterCrop, variant: .tertiary) { model.center() }
                AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
            }
        }
    }

    private var aspectBinding: Binding<CropAspect> {
        Binding(get: { model.aspect }, set: { model.select($0) })
    }

    private static let aspects: [AppSegmentedPicker<CropAspect>.Option] = [
        .init(value: .free, label: .aspectFree), .init(value: .original, label: .aspectOriginal),
        .init(value: .square, label: .aspectSquare), .init(value: .fourThree, label: .aspectFourThree),
        .init(value: .sixteenNine, label: .aspectSixteenNine),
        .init(value: .nineSixteen, label: .aspectNineSixteen),
        .init(value: .threeFour, label: .aspectThreeFour), .init(value: .fourFive, label: .aspectFourFive),
        .init(value: .threeTwo, label: .aspectThreeTwo), .init(value: .twoThree, label: .aspectTwoThree)
    ]
}
