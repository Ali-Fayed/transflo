import SwiftUI
import TransfloDomain

/// Getting Started replays the five-page flow; only Done marks the first-run setup complete.
struct WelcomeView: View {
    @Bindable var model: OnboardingViewModel
    let customization: CustomizationViewModel
    let openSettings: () -> Void
    let dismiss: () -> Void
    @Environment(Localizer.self) private var localizer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppDimensions.Spacing.xLarge) {
            page.id(PageIdentity(presentation: model.presentation, page: model.page))
                .transition(pageTransition)
                .frame(height: AppDimensions.Onboarding.contentHeight)
                .clipped()
            SettingsDivider()
            HStack(spacing: AppDimensions.Spacing.medium) {
                if model.canGoBack { AppButton(key: .onboardingBack, variant: .tertiary) { model.back() } }
                AppButton(key: .welcomeOpenSettings, variant: .tertiary, action: openSettings)
                Spacer()
                AppPageDots(page: model.page, count: OnboardingViewModel.pageCount)
                Spacer()
                AppButton(key: model.isLastPage ? .onboardingDone : .onboardingContinue, variant: .primary) {
                    if model.isLastPage {
                        if model.finish() { dismiss() }
                    } else { model.next() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppDimensions.Onboarding.padding)
        .frame(width: AppDimensions.Onboarding.width)
        .background(AppWindowBackdrop().ignoresSafeArea())
        .animation(reduceMotion ? nil : AppAnimations.onboarding, value: model.page)
    }

    @ViewBuilder private var page: some View {
        switch model.page {
        case 0: AppOnboardingHero(customization: customization)
        case 1: wheelPage(.convert)
        case 2: wheelPage(.tools)
        case 3: wheelPage(.actions)
        default:
            AppOnboardingPage {
                AppMenuBarIllustration(caption: .welcomeMenuBarCaption).appEntrance(step: 0)
            } content: {
                AppText(.onboardingFinish, style: .welcomeTitle).appEntrance(step: 1)
                AppText(.onboardingFinishDescription, color: .secondary).appEntrance(step: 2)
                HStack {
                    AppText(.settingsLaunchAtLogin, style: .headline)
                    Spacer()
                    AppToggle(key: .settingsLaunchAtLogin, isOn: Binding(
                        get: { model.launchAtLogin }, set: { model.setLaunchAtLoginEnabled($0) }
                    ))
                }
                .appEntrance(step: 3)
                if let error = model.errorState { SettingsFootnote(message: error.messageKey, tone: .danger) }
                SettingsFootnote(message: .onboardingFolderPermissions).appEntrance(step: 4)
            }
        }
    }

    private func wheelPage(_ wheel: WheelKind) -> some View {
        AppOnboardingPage {
            AppWheelSample(wedges: OnboardingPresentation.wedges(for: wheel),
                           title: WheelPresentation.title(for: wheel), glyph: glyph(for: wheel),
                           highlightedIndex: wheel == .tools ? 1 : nil)
        } content: {
            AppText(WheelPresentation.title(for: wheel), style: .welcomeTitle).appEntrance(step: 1)
            AppText(OnboardingPresentation.description(for: wheel), color: .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .appEntrance(step: 2)
            AppText(.onboardingDrag, style: .headline).appEntrance(step: 3)
            HStack(spacing: AppDimensions.Spacing.medium) {
                AppText(.onboardingTap, style: .headline)
                if let key = model.key(for: wheel) {
                    AppKeycap(glyph: WheelPresentation.glyph(for: key), demonstratesTap: true)
                        .accessibilityLabel(localizer.string(OnboardingPresentation.keyName(key)))
                }
            }
            .appEntrance(step: 4)
            AppText(wheel == .tools ? .onboardingToolsDrop : .onboardingDrop, style: .caption, color: .secondary)
                .fixedSize(horizontal: false, vertical: true)
                .appEntrance(step: 5)
        }
    }

    private func glyph(for wheel: WheelKind) -> String {
        model.key(for: wheel).map { WheelPresentation.glyph(for: $0) } ?? ""
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion, AppAnimations.onboarding != nil else { return .identity }
        let fromTrailing = model.movingForward != localizer.isRightToLeft
        return .asymmetric(insertion: .move(edge: fromTrailing ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: fromTrailing ? .leading : .trailing).combined(with: .opacity))
    }
}

/// Identity of the visible page: a new presentation replays its entrance even on the same page.
private struct PageIdentity: Hashable {
    let presentation: Int
    let page: Int
}
