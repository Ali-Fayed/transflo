import SwiftUI
import TransfloDomain

/// One home for preferences: controls, output defaults, wheels, live compatibility and app information.
struct SettingsView: View {
    let viewModel: SettingsViewModel
    let keys: KeySettingsViewModel
    let customization: CustomizationViewModel
    let tools: ToolPreferencesViewModel
    let wheel: WheelVisibilityViewModel
    let updates: UpdateSettingsViewModel
    let catalog: SettingsCatalogViewModel
    var recipes: RecipesViewModel?
    var watchFolders: WatchFoldersViewModel?
    let checkForUpdates: () -> Void
    let openPrivacy: () -> Void
    let openSupport: () -> Void
    var navigation = SettingsNavigation()
    @State private var contentHeights: [Tab: CGFloat] = [:]
    private typealias Tab = SettingsNavigation.Tab
    private var selectedTab: Tab { navigation.selectedTab }

    var body: some View {
        VStack(spacing: .zero) {
            AppSegmentedPicker(key: .settingsTitle, selection: Binding(
                get: { navigation.selectedTab }, set: { navigation.selectedTab = $0 }), options: Self.tabs)
                .frame(height: AppDimensions.Window.settingsTabChrome)
                .accessibilityIdentifier("settings.tabs")
            selectedPage
        }
        .padding(AppDimensions.Spacing.medium)
        .frame(width: AppDimensions.Window.settingsWidth, height: windowHeight)
        .background(AppWindowBackdrop().ignoresSafeArea())
        .animation(AppAnimations.standard, value: viewModel.state.errorState)
    }

    private static let tabs: [AppSegmentedPicker<Tab>.Option] = [
        .init(value: .general, label: .settingsGeneralSection),
        .init(value: .wheel, label: .settingsWheel), .init(value: .recipes, label: .settingsRecipes),
        .init(value: .compatibility, label: .settingsCompatibility),
        .init(value: .about, label: .settingsAboutSection)
    ]

    @ViewBuilder private var selectedPage: some View {
        switch selectedTab {
        case .general: page(.general) { general }
        case .wheel:
            page(.wheel) {
                VStack(spacing: AppDimensions.Spacing.xLarge) {
                    WheelVisibilitySettingsView(model: wheel)
                    WheelStyleSettingsView(viewModel: customization)
                }
            }
        case .recipes:
            page(.recipes) {
                VStack(spacing: AppDimensions.Spacing.xLarge) {
                    if let recipes { RecipesSettingsView(model: recipes) }
                    if let watchFolders, recipes?.draft == nil { WatchFoldersSettingsView(model: watchFolders) }
                }
            }
        case .compatibility: page(.compatibility) { CompatibilitySettingsView(model: catalog) }
        case .about: page(.about) { about }
        }
    }

    private func page<Content: View>(_ tab: Tab, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .fixedSize(horizontal: false, vertical: true)
                .padding(AppDimensions.Spacing.xLarge)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    contentHeights[tab] = height
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.top)
        .id(tab)
    }

    private var windowHeight: CGFloat {
        let content = contentHeights[selectedTab] ?? AppDimensions.Window.settingsMinContentHeight
        return min(content + AppDimensions.Window.settingsTabChrome + AppDimensions.Spacing.medium * 2,
                   AppDimensions.Window.settingsMaxHeight)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xLarge) {
            SettingsSection(title: .settingsGeneralSection) {
                SettingsRow(label: .settingsLanguage) {
                    AppSegmentedPicker(key: .settingsLanguage, selection: language, options: Self.languageOptions)
                }
                SettingsDivider()
                SettingsRow(label: .settingsLaunchAtLogin) {
                    AppToggle(key: .settingsLaunchAtLogin, isOn: launchAtLogin)
                }
                if let error = viewModel.state.errorState {
                    SettingsFootnote(message: error.messageKey, tone: .danger)
                }
                SettingsDivider()
                SettingsRow(label: .settingsWheelHaptics) {
                    AppToggle(key: .settingsWheelHaptics, isOn: Binding(
                        get: { customization.preferences.wheelHaptics },
                        set: { value in customization.update { $0.wheelHaptics = value } }))
                }
                SettingsFootnote(message: .settingsWheelHapticsHint)
                SettingsDivider()
                SettingsRow(label: .settingsWheelSound) {
                    AppToggle(key: .settingsWheelSound, isOn: Binding(
                        get: { customization.preferences.wheelSound },
                        set: { value in customization.update { $0.wheelSound = value } }))
                }
            }
            OutputPreferencesView(model: tools)
            CustomizationSettingsView(settings: viewModel, viewModel: customization)
            KeySettingsSection(viewModel: keys)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xLarge) {
            SettingsSection(title: .settingsAboutSection) {
                HStack(spacing: AppDimensions.Spacing.large) {
                    AppAppIcon(size: AppDimensions.Window.aboutIconSize)
                    VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
                        AppText(.appName, style: .title)
                        AppText(.settingsVersion, arguments: versionArguments, color: .secondary)
                    }
                }
                SettingsFootnote(message: .settingsAboutDescription)
                HStack {
                    AppButton(key: .menuPrivacy, variant: .tertiary, action: openPrivacy)
                    AppButton(key: .menuSupport, variant: .tertiary, action: openSupport)
                }
            }
            SettingsSection(title: .settingsUpdatesSection) {
                SettingsRow(label: .settingsAutomaticUpdates) {
                    AppToggle(key: .settingsAutomaticUpdates, isOn: automaticUpdates)
                }
                SettingsDivider()
                SettingsRow(label: .menuCheckUpdates) {
                    AppButton(key: .settingsCheckNow, action: checkForUpdates)
                }
            }
        }
    }

    private static let languageOptions: [AppSegmentedPicker<AppLanguage>.Option] = [
        .init(value: .english, label: .languageEnglish), .init(value: .arabic, label: .languageArabic)
    ]
    private var language: Binding<AppLanguage> {
        Binding(get: { viewModel.state.language }, set: { viewModel.selectLanguage($0) })
    }
    private var launchAtLogin: Binding<Bool> {
        Binding(get: { viewModel.state.launchAtLogin }, set: { viewModel.setLaunchAtLoginEnabled($0) })
    }
    private var automaticUpdates: Binding<Bool> {
        Binding(get: { updates.checksAutomatically }, set: { updates.setChecksAutomatically($0) })
    }
    private var versionArguments: [String] { [viewModel.state.version.marketing, viewModel.state.version.build] }
}
