import SwiftUI
import TransfloDomain

/// Native grouped preferences, with system menus and separate Customization and About destinations.
struct MobileSettingsView: View {
    @Environment(Localizer.self) private var localizer
    let viewModel: MobileSettingsViewModel
    let customization: CustomizationViewModel
    /// Shared models keep settings and recipe drafts stable across redraws.
    let destinations: MobileSettingsDestinations

    var body: some View {
        Form {
            Section {
                Picker(selection: language) {
                    Text(localizer.string(.languageEnglish)).tag(AppLanguage.english)
                    Text(localizer.string(.languageArabic)).tag(AppLanguage.arabic)
                } label: {
                    Label(localizer.string(.settingsLanguage), systemImage: "globe")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("mobile.settings.language")
                Picker(selection: appearance) {
                    Text(localizer.string(.appearanceSystem)).tag(AppearanceMode.system)
                    Text(localizer.string(.appearanceLight)).tag(AppearanceMode.light)
                    Text(localizer.string(.appearanceDark)).tag(AppearanceMode.dark)
                } label: {
                    Label(localizer.string(.settingsAppearance), systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("mobile.settings.appearance")
            } header: {
                Text(localizer.string(.settingsGeneralSection))
            }
            Section {
                NavigationLink {
                    MobileOutputSettingsView(model: destinations.output)
                } label: { Label(localizer.string(.settingsOutput), systemImage: "square.and.arrow.down") }
                .accessibilityIdentifier("mobile.settings.output")
                NavigationLink {
                    MobileRecipesView(model: destinations.recipes)
                } label: { Label(localizer.string(.settingsRecipes), systemImage: "list.bullet.rectangle") }
                .accessibilityIdentifier("mobile.settings.recipes")
                NavigationLink {
                    MobileActionCustomizationView(model: destinations.wheel)
                } label: {
                    Label(localizer.string(.mobileCustomizeActions), systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("mobile.settings.actionCustomization")
                NavigationLink {
                    MobileCustomizationView(customization: customization)
                } label: {
                    Label(localizer.string(.settingsCustomization), systemImage: AppSymbol.customization.rawValue)
                }
                .accessibilityIdentifier("mobile.settings.customization")
            }
            Section {
                NavigationLink {
                    MobileAboutView(version: viewModel.state.version)
                } label: {
                    HStack {
                        Label(localizer.string(.settingsAboutSection), systemImage: "info.circle")
                        Spacer(minLength: AppDimensions.Spacing.small)
                        AppText(verbatim: viewModel.state.version.marketing, style: .caption, color: .secondary)
                    }
                }
                .accessibilityIdentifier("mobile.settings.about")
            }
        }
        .appScreenBackground()
        .tint(AppColors.accent)
        .mobileNavigationBar(.flowSettingsTab)
        .accessibilityIdentifier("mobile.settings")
    }

    private var language: Binding<AppLanguage> {
        Binding(get: { viewModel.state.language }, set: { AppFeedback.selection(); viewModel.selectLanguage($0) })
    }

    private var appearance: Binding<AppearanceMode> {
        Binding(get: { viewModel.state.appearance }, set: { AppFeedback.selection(); viewModel.selectAppearance($0) })
    }
}

#if DEBUG
#Preview {
    MobilePreviews.settings
}
#endif
