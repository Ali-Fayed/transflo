import SwiftUI
import TransfloDomain

/// Audio and video editing on iPhone and iPad: Trim, Change Speed, Snapshot and Split, built from the
/// native mobile sliders with precise labeled values.
struct MobileMediaControls: View {
    @Bindable var model: MobileToolEditorModel
    @Environment(Localizer.self) private var localizer

    static let speeds: [Double] = [0.25, 0.5, 0.75, 1.25, 1.5, 2, 3, 4]

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
            switch model.tool {
            case .trim: trim
            case .changeSpeed: speed
            case .snapshot:
                MobileEditorSlider(title: .editorFrameAt, value: $model.snapshotTime,
                                   range: 0...max(0.1, model.duration),
                          valueText: timestamp(model.snapshotTime))
            case .split:
                MobileEditorSlider(title: .mobileSplitEvery, value: $model.splitEvery,
                          range: 1...max(2, model.duration / 2), valueText: timestamp(model.splitEvery))
                AppText(.editorParts, style: .caption, color: .secondary)
                AppText(verbatim: String(model.splitPoints.count + 1), style: .title)
            default: EmptyView()
            }
        }
    }

    private func timestamp(_ seconds: Double) -> String {
        TimeLabel.wholeSeconds(seconds)
    }

    private var trim: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            MobileTrimRange(start: $model.trimStart, end: $model.trimEnd, duration: model.duration)
            AppText(.editorRange, arguments: [timestamp(model.trimStart), timestamp(model.trimEnd),
                                              timestamp(model.trimEnd - model.trimStart)],
                    style: .caption, color: .secondary)
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: localizer.isRightToLeft) {
                AppButton(key: .editorFirstHalf, variant: .tertiary) {
                    model.trimStart = 0
                    model.trimEnd = model.duration / 2
                }
                AppButton(key: .editorLastHalf, variant: .tertiary) {
                    model.trimStart = model.duration / 2
                    model.trimEnd = model.duration
                }
                AppButton(key: .editorReset, variant: .tertiary) {
                    model.trimStart = 0
                    model.trimEnd = model.duration
                }
            }
        }
    }

    private var speed: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            AppText(.editorSpeed)
            AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: localizer.isRightToLeft) {
                ForEach(Self.speeds, id: \.self) { value in
                    AppButton(label: .formatted(.editorSpeedValue, [value.formatted(.number)]),
                              variant: value == model.speed ? .primary : .tertiary) { model.speed = value }
                }
            }
            AppText(.editorNewLength, arguments: [timestamp(model.duration / model.speed)],
                    style: .caption, color: .secondary)
        }
    }
}
