import SwiftUI
import TransfloDomain

struct MobileActionCustomizationView: View {
    let model: WheelVisibilityViewModel
    @Environment(Localizer.self) private var localizer

    var body: some View {
        List {
            Section {
                AppSegmentedPicker(key: .mobileChooseAction, selection: Binding(
                    get: { model.wheel }, set: { model.select($0) }
                ), options: model.availableWheels.map {
                    .init(value: $0, label: WheelPresentation.title(for: $0))
                })
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            }
            Section {
                HStack {
                    AppButton(key: .mobileShowAll, variant: .tertiary) { model.showAll() }
                    Spacer()
                    AppButton(key: .mobileHideAll, variant: .tertiary) { model.hideAll() }
                }
                AppText(.mobileVisibilityDetail, style: .caption, color: .secondary)
                if model.isWheelEmpty { AppText(.mobileVisibilityEmpty, style: .caption, color: .danger) }
            }
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.rows) { row in
                        Toggle(isOn: Binding(get: { model.isVisible(row) }, set: {
                            AppFeedback.selection()
                            model.setVisible(row, $0)
                        })) {
                            AppText(row.label)
                        }
                        .tint(AppColors.accent)
                        .accessibilityIdentifier("mobile.visibility.\(row.id)")
                    }
                } header: {
                    if let title = group.title { AppText(title, style: .caption, color: .secondary) }
                }
            }
            if model.supportsOrdering {
                Section {
                    Toggle(localizer.string(.mobileRecentFirst), isOn: Binding(
                        get: { model.usage.lastUsedFirst }, set: {
                            AppFeedback.selection(); model.setLastUsedFirst($0)
                        }))
                    Toggle(localizer.string(.mobileFrequentFirst), isOn: Binding(
                        get: { model.usage.ordersByFrequency }, set: {
                            AppFeedback.selection(); model.setOrdersByFrequency($0)
                        }))
                }
                .tint(AppColors.accent)
            }
        }
        .appScreenBackground()
        .mobileNavigationBar(.mobileCustomizeActions)
        .accessibilityIdentifier("mobile.actionCustomization")
    }
}
