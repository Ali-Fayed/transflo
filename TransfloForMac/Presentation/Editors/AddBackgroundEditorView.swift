import SwiftUI
import TransfloDomain

/// Live background composition beside compact controls; the source never changes until Save.
struct AddBackgroundEditorView: View {
    @Bindable var model: AddBackgroundEditorViewModel
    @Environment(Localizer.self) private var localizer

    var body: some View {
        HStack(alignment: .top, spacing: AppDimensions.Spacing.xLarge) {
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
                AppPreviewImage(data: model.composedPreview)
                    .modifier(AppPreviewFrame(aspectRatio: model.canvasAspectRatio))
                if model.isRendering { AppText(.beautifyRendering, style: .caption, color: .secondary) }
                if let error = model.errorKey {
                    SettingsFootnote(message: error, tone: .danger)
                    AppButton(key: .beautifyRetry, variant: .tertiary) { Task { await model.load() } }
                }
            }
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
                AppText(.editorBackground, style: .headline)
                AppPresetGrid(fill: model.style.fill) { preset in model.update { $0.fill = .gradient(preset) } }
                AppColorSwatches(selection: $model.color)
                AppCustomColorPicker(selection: $model.color)
                AppChipGroup(key: .editorComposition, selection: composition, options: Self.compositions)
                AppSlider(label: .beautifyPadding, value: value(\.padding),
                          range: TransfloDomain.BackgroundStyle.paddingRange,
                          valueText: percentage(model.style.padding))
                AppSlider(label: .beautifyCorners, value: value(\.corners),
                          range: TransfloDomain.BackgroundStyle.cornerRange,
                          valueText: percentage(model.style.corners))
                AppSlider(label: .beautifyShadow, value: value(\.shadow),
                          range: TransfloDomain.BackgroundStyle.shadowRange,
                          valueText: model.style.shadow.formatted(.number.precision(.fractionLength(0))
                            .locale(localizer.locale)))
                AppText(.beautifyRatio, style: .headline)
                AppChipGroup(key: .beautifyRatio,
                             selection: Binding(get: { model.style.ratio }, set: { ratio in
                                 model.update { $0.ratio = ratio }
                             }), options: Self.ratios)
                AppButton(key: .editorReset, variant: .tertiary) { model.reset() }
            }
            .frame(width: AppDimensions.Beautify.controlsWidth)
        }
        .onDisappear { model.cancelPreview() }
    }

    private var composition: Binding<Int> {
        Binding(get: { model.composition }, set: { model.applyComposition($0) })
    }
    private static let compositions: [AppSegmentedPicker<Int>.Option] = [
        .init(value: 0, label: .editorMinimal), .init(value: 1, label: .editorBalanced),
        .init(value: 2, label: .editorSpacious)
    ]

    private func value(_ keyPath: WritableKeyPath<TransfloDomain.BackgroundStyle, Double>) -> Binding<Double> {
        Binding(get: { model.style[keyPath: keyPath] }, set: { value in
            model.update { $0[keyPath: keyPath] = value }
        })
    }

    private func percentage(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)).locale(localizer.locale))
    }

    private static let ratios: [AppSegmentedPicker<BackgroundCanvasRatio>.Option] = [
        .init(value: .automatic, label: .beautifyAuto), .init(value: .square, label: .aspectSquare),
        .init(value: .sixteenNine, label: .aspectSixteenNine), .init(value: .fourFive, label: .aspectFourFive),
        .init(value: .nineSixteen, label: .aspectNineSixteen),
        .init(value: .fourThree, label: .aspectFourThree), .init(value: .threeFour, label: .aspectThreeFour),
        .init(value: .threeTwo, label: .aspectThreeTwo), .init(value: .twoThree, label: .aspectTwoThree)
    ]
}
