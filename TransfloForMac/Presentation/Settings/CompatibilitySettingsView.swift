import SwiftUI
import TransfloDomain

/// Readable, scrollable source-to-output matrix derived from actual conversion paths.
struct CompatibilitySettingsView: View {
    @Environment(Localizer.self) private var localizer
    @Bindable var model: SettingsCatalogViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
            HStack {
                AppText(.settingsCompatibility, style: .title)
                Spacer()
                AppMenuPicker(key: .settingsFormatFamily, selection: $model.family,
                              options: FormatFamily.allCases.map {
                                  .init(value: $0, label: SettingsCatalogViewModel.label(for: $0))
                              })
                .accessibilityIdentifier("settings.compatibility.family")
            }
            SettingsFootnote(message: .settingsCompatibilityHint)
            ScrollView([.horizontal, .vertical]) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        cell("↓ / →", header: true)
                        ForEach(model.matrixTargets) { target in cell(target.displayName, header: true) }
                    }
                    ForEach(model.matrixSources) { source in
                        GridRow {
                            cell(source.displayName, header: true)
                            ForEach(model.matrixTargets) { target in
                                let supported = model.supports(source.id, target.id)
                                cell(supported ? "✓" : "–", header: false)
                                    .accessibilityLabel(localizer.string(
                                        supported ? .settingsRouteSupported : .settingsRouteUnavailable,
                                        arguments: [source.displayName, target.displayName]))
                            }
                        }
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .frame(height: min(360, CGFloat(model.matrixSources.count + 1) * 38))
            .accessibilityIdentifier("settings.compatibility.matrix")
            SettingsFootnote(message: .settingsCompatibilityLegend)
        }
    }

    private func cell(_ value: String, header: Bool) -> some View {
        AppText(verbatim: value, style: header ? .caption : .body, color: header ? .primary : .secondary)
            .frame(width: 68, height: 36)
            .background(header ? AppColors.divider : .clear)
            .overlay(Rectangle().stroke(AppColors.divider, lineWidth: 0.5))
    }
}
