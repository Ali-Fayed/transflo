import SwiftUI

/// A touch-first tour of selecting files, choosing actions and saving results.
struct MobileOnboardingView: View {
    let model: MobileOnboardingViewModel
    let customization: CustomizationViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppText(.appName, style: .headline)
                Spacer()
                AppButton(key: .flowSkip, variant: .tertiary, action: model.skip)
                    .accessibilityIdentifier("mobile.onboarding.skip")
            }
            .padding(AppDimensions.Spacing.xLarge)
            // At least a screen tall, so short screens start at the top and tall ones stay centered.
            GeometryReader { proxy in
                ScrollView {
                    Group {
                        if sizeClass == .regular {
                            HStack(spacing: AppDimensions.Mobile.sectionGap) {
                                illustration.frame(maxWidth: .infinity)
                                copy.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            VStack(spacing: AppDimensions.Spacing.xLarge) {
                                illustration
                                copy
                            }
                        }
                    }
                    .id(model.page)
                    .transition(.opacity.combined(with: .offset(y: AppDimensions.Onboarding.entranceOffset)))
                    .padding(AppDimensions.Spacing.xLarge)
                    .frame(maxWidth: AppDimensions.Mobile.tourWidth)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            HStack(spacing: AppDimensions.Spacing.large) {
                if model.page > 0 {
                    AppButton(key: .onboardingBack, variant: .tertiary, action: model.back)
                        .accessibilityIdentifier("mobile.onboarding.back")
                }
                Spacer()
                AppPageDots(page: model.page, count: MobileOnboardingViewModel.pageCount)
                Spacer()
                AppButton(key: model.isLastPage ? .flowStart : .onboardingContinue, variant: .primary) {
                    if model.isLastPage { model.finish() } else { model.next() }
                }
                .accessibilityIdentifier("mobile.onboarding.next")
            }
            .padding(AppDimensions.Spacing.xLarge)
        }
        .background(AppColors.background.ignoresSafeArea())
        .background(AppColors.accent.opacity(0.04))
        .animation(AppAnimations.onboarding, value: model.page)
        .interactiveDismissDisabled()
    }

    private var illustration: some View {
        MobileActionTourPreview(stage: model.page)
            .padding(AppDimensions.Spacing.xLarge)
            .frame(maxWidth: .infinity)
            .background(AppColors.accent.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: AppDimensions.Mobile.dropAreaRadius))
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xLarge) {
            AppText(title, style: .welcomeTitle).appEntrance(step: 0)
                .accessibilityAddTraits(.isHeader)
            AppText(detail, color: .secondary)
                .fixedSize(horizontal: false, vertical: true).appEntrance(step: 1)
            if model.isLastPage {
                AppAccentPicker(selection: Binding(get: { customization.preferences.accentHex },
                                                   set: { hex in customization.update { $0.accentHex = hex } }))
                SettingsRow(label: .settingsReduceMotion) {
                    AppToggle(key: .settingsReduceMotion, isOn: Binding(
                        get: { customization.preferences.reduceMotion },
                        set: { enabled in customization.update { $0.reduceMotion = enabled } }
                    ))
                }
            } else {
                HStack(spacing: AppDimensions.Spacing.small) {
                    AppIcon(symbol: .localFiles).foregroundStyle(AppColors.accent)
                    AppText(.flowLocal, style: .caption, color: .secondary)
                }
                .appEntrance(step: 2)
            }
        }
    }

    private var title: L10nKey {
        switch model.page {
        case 0: .mobileWelcome
        case 1: .mobilePickTitle
        case 2: .flowShareTitle
        default: .flowColorTitle
        }
    }

    private var detail: L10nKey {
        switch model.page {
        case 0: .mobileWelcomeDetail
        case 1: .mobilePickDetail
        case 2: .mobileShareDetail
        default: .mobileColorDetail
        }
    }
}
