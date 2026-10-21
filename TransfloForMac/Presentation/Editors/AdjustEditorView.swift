import AppKit
import SwiftUI
import TransfloDomain

/// Compact preview and scrollable grouped controls keep the action bar on screen.
struct AdjustEditorView: View {
    @Environment(Localizer.self) private var localizer
    @Bindable var model: AdjustEditorViewModel

    private var availableHeight: CGFloat { NSScreen.main?.visibleFrame.height ?? 800 }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppPreviewImage(data: model.displayedThumbnail)
                .frame(height: min(230, max(130, availableHeight * 0.28)))
                .accessibilityLabel(localizer.string(model.showOriginal ? .editorOriginal : .editorAdjusted))
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                AppButton(key: .editorMonochrome, variant: .tertiary) {
                    model.values = ImageAdjustments(exposure: 0, contrast: 1.1, saturation: 0)
                }
                AppButton(key: .editorWarmPortrait, variant: .tertiary) {
                    model.values = ImageAdjustments(exposure: 0.1, contrast: 1, saturation: 1,
                                                    shadows: 0.15, temperature: 0.2, vibrance: 0.1)
                }
                AppButton(key: .editorBrighten, variant: .tertiary) {
                    model.values = ImageAdjustments(exposure: 0.4, contrast: 1, saturation: 1, shadows: 0.2)
                }
            }
            HStack {
                AppText(.editorOriginal)
                AppToggle(key: .editorOriginal, isOn: $model.showOriginal)
                    .accessibilityIdentifier("transflo.adjust.original")
                Spacer()
                AppButton(key: .editorReset, variant: .tertiary, isEnabled: !model.adjustments.isNeutral) {
                    model.reset()
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
                    section(.editorLight, controls: PhotoAdjustmentControl.light)
                    section(.editorColorGroup, controls: PhotoAdjustmentControl.color)
                    section(.editorDetail, controls: PhotoAdjustmentControl.detail)
                }
                .padding(.trailing, AppDimensions.Spacing.small)
                .padding(.vertical, AppDimensions.Spacing.xSmall)
            }
            .frame(height: min(290, max(120, availableHeight - 460)))
        }
        .task(id: model.adjustments) {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await model.refreshPreview()
        }
    }

    private func section(_ title: L10nKey, controls: [PhotoAdjustmentControl]) -> some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(title, style: .headline, color: .secondary)
            ForEach(controls) { control in
                HStack(alignment: .bottom, spacing: AppDimensions.Spacing.small) {
                    AppSlider(label: control.label, value: binding(control.path), range: control.range,
                              valueText: valueText(control), defaultValue: control.neutral)
                    AppIconButton(symbol: .reset,
                                  content: .formatted(.editorResetControl, [localizer.string(control.label)])) {
                        model.values[keyPath: control.path] = control.neutral
                    }
                    .disabled(model.values[keyPath: control.path] == control.neutral)
                    .accessibilityIdentifier("transflo.adjust.reset.\(control.label.rawValue)")
                }
            }
        }
    }

    private func binding(_ path: WritableKeyPath<ImageAdjustments, Double>) -> Binding<Double> {
        Binding(get: { model.values[keyPath: path] }, set: { model.values[keyPath: path] = $0 })
    }

    private func valueText(_ control: PhotoAdjustmentControl) -> String {
        let value = model.values[keyPath: control.path]
        if control.label == .editorExposure {
            return value.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + " EV"
        }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }
}
