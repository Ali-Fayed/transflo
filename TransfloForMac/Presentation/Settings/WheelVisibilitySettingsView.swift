import SwiftUI
import TransfloDomain

/// Settings › Wheel: pick a wheel, then tick the options it should show.
struct WheelVisibilitySettingsView: View {
    let model: WheelVisibilityViewModel

    var body: some View {
        SettingsSection(title: .settingsWheelSection) {
            AppSegmentedPicker(key: .settingsWheelChoose, selection: wheel, options: Self.wheels)
                .accessibilityIdentifier("settings.wheel.picker")
            SettingsFootnote(message: model.wheel == .convert ? .settingsWheelConvertHint : .settingsWheelHint)
            if model.supportsOrdering { ordering }
            SettingsDivider()
            header
            if model.isWheelEmpty {
                SettingsFootnote(message: .settingsWheelEmpty, tone: .danger)
            }
            VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
                ForEach(model.groups) { group in
                    checklist(group)
                }
            }
            .id(model.wheel)
        }
        .animation(AppAnimations.standard, value: model.isWheelEmpty)
    }

    private var header: some View {
        HStack(spacing: AppDimensions.Spacing.small) {
            AppText(.settingsWheelShownCount, arguments: [String(model.shownCount), String(model.totalCount)],
                    style: .headline)
                .accessibilityIdentifier("settings.wheel.count")
            Spacer(minLength: AppDimensions.Spacing.small)
            AppButton(key: .settingsWheelShowAll, variant: .tertiary,
                      isEnabled: model.shownCount < model.totalCount) { model.showAll() }
            AppButton(key: .settingsWheelHideAll, variant: .tertiary,
                      isEnabled: model.shownCount > 0) { model.hideAll() }
        }
    }

    private func checklist(_ group: WheelVisibilityViewModel.Group) -> some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            AppText(group.title ?? WheelPresentation.title(for: model.wheel), style: .caption, color: .secondary)
            // Eager layout lets the content-sized Settings window measure every category,
            // including rows initially below the viewport, before changing wheel segments.
            Grid(alignment: .leading, horizontalSpacing: AppDimensions.Spacing.large,
                 verticalSpacing: AppDimensions.Spacing.small) {
                ForEach(Array(stride(from: 0, to: group.rows.count, by: 2)), id: \.self) { start in
                    GridRow {
                        ForEach(group.rows[start..<min(start + 2, group.rows.count)]) { row in
                            HStack(spacing: AppDimensions.Spacing.xSmall) {
                                AppCheckbox(label: row.label, symbol: row.symbol, isOn: binding(for: row))
                                    .accessibilityIdentifier("settings.wheel.\(row.id)")
                                if model.supportsOrdering { pin(row) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    /// Pinned options open first on their wheel, in the order they were pinned.
    private var ordering: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            SettingsDivider()
            SettingsRow(label: .settingsWheelLastUsedFirst) {
                AppToggle(key: .settingsWheelLastUsedFirst, isOn: Binding(
                    get: { model.usage.lastUsedFirst }, set: { model.setLastUsedFirst($0) }))
            }
            SettingsRow(label: .settingsWheelByFrequency) {
                AppToggle(key: .settingsWheelByFrequency, isOn: Binding(
                    get: { model.usage.ordersByFrequency }, set: { model.setOrdersByFrequency($0) }))
            }
            SettingsFootnote(message: .settingsWheelOrderHint)
        }
    }

    private func pin(_ row: WheelVisibilityViewModel.Row) -> some View {
        let pinned = model.isPinned(row)
        return AppIconButton(symbol: pinned ? .starFilled : .star,
                             content: .key(pinned ? .settingsWheelUnpin : .settingsWheelPin)) {
            model.setPinned(row, !pinned)
        }
        .accessibilityIdentifier("settings.wheel.pin.\(row.id)")
        .accessibilityAddTraits(pinned ? .isSelected : [])
    }

    private func binding(for row: WheelVisibilityViewModel.Row) -> Binding<Bool> {
        Binding(get: { model.isVisible(row) }, set: { model.setVisible(row, $0) })
    }

    private var wheel: Binding<WheelKind> {
        Binding(get: { model.wheel }, set: { model.select($0) })
    }

    private static let wheels: [AppSegmentedPicker<WheelKind>.Option] = [
        .init(value: .convert, label: .wheelConvert), .init(value: .tools, label: .wheelTools),
        .init(value: .actions, label: .wheelActions)
    ]
}
