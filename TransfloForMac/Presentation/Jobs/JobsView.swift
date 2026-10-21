import SwiftUI

/// The Jobs window: recent jobs on a glass card, Cancel All and Clear Finished below.
struct JobsView: View {
    let viewModel: JobListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.medium) {
            AppText(.jobsTitle, style: .title)
            if viewModel.rows.isEmpty {
                AppHistoryEmptyState(message: .jobsEmpty)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.rows) { row in
                            AppJobRow(
                                ring: row.ring, title: row.operation, detail: row.files, status: row.status,
                                isFailed: row.isFailed, timeLeft: row.timeLeft,
                                onCancel: row.canCancel ? { viewModel.cancel(row.id) } : nil,
                                onReveal: row.canReveal ? { viewModel.reveal(row.id) } : nil,
                                onUndo: row.canUndo ? { viewModel.undo(row.id) } : nil
                            )
                            if row.id != viewModel.rows.last?.id { SettingsDivider() }
                        }
                    }
                    .padding(.horizontal, AppDimensions.Spacing.large)
                    .padding(.vertical, AppDimensions.Spacing.small)
                }
                .appGlass(.card, in: RoundedRectangle(cornerRadius: AppDimensions.Radius.large))
            }
            HStack(spacing: AppDimensions.Spacing.small) {
                Spacer()
                AppButton(key: .jobsClearFinished, variant: .tertiary, isEnabled: viewModel.hasFinishedJobs) {
                    viewModel.clearFinished()
                }
                AppButton(key: .jobsCancelAll, variant: .tertiary, isEnabled: viewModel.hasActiveJobs) {
                    viewModel.cancelAll()
                }
            }
        }
        .padding(AppDimensions.Spacing.xLarge)
        .frame(width: AppDimensions.Jobs.windowWidth, height: AppDimensions.Jobs.windowHeight)
        .background(AppWindowBackdrop().ignoresSafeArea())
    }
}
