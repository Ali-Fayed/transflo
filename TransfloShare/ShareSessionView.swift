import SwiftUI

/// The share sheet's screen: the shared files' progress and results, with the mobile action picker above them.
struct ShareSessionView: View {
    let session: ShareSession

    private var container: MobileContainer { session.container }

    var body: some View {
        @Bindable var coordinator = container.coordinator
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppDimensions.Spacing.large) {
                    if session.phase == .loading { AppSpinner() }
                    if let message = session.home.state.message {
                        SettingsFootnote(message: message, tone: .danger)
                    }
                    ForEach(session.jobs.rows) { row in
                        AppJobRow(ring: row.ring, title: row.operation, detail: row.files, status: row.status,
                                  isFailed: row.isFailed, timeLeft: row.timeLeft,
                                  onCancel: row.canCancel ? { session.jobs.cancel(row.id) } : nil,
                                  onReveal: row.canReveal ? { session.jobs.reveal(row.id) } : nil)
                    }
                }
                .padding(AppDimensions.Spacing.xLarge)
                .frame(maxWidth: AppDimensions.Mobile.readableWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    AppButton(key: .onboardingDone, variant: .primary, isEnabled: !session.isBusy,
                              action: session.finish)
                }
            }
        }
        .overlay {
            MobileActionPicker(presenter: container.wheel.presenter, viewModel: container.wheel.viewModel,
                               coordinator: container.wheel.coordinator)
        }
        .animation(AppAnimations.standard, value: container.wheel.presenter.isShown)
        .onChange(of: container.wheel.presenter.isShown) { _, shown in
            if !shown { session.wheelClosed() }
        }
        .toolEditors(container.wheel.choices)
        .resultPresentation($coordinator.sharing, onDismiss: session.resultDismissed)
        .onChange(of: container.wheel.choices.isPresented) { _, shown in
            container.coordinator.setResultsBlocked(shown)
        }
        .preferredColorScheme(container.appearance.colorScheme)
    }
}
