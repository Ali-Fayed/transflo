import SwiftUI
import TransfloDomain

/// Activity: work in progress, this session's results, and earlier results, each with a thumbnail.
struct MobileJobsView: View {
    @Environment(Localizer.self) private var localizer
    let viewModel: JobListViewModel
    var history: MobileHistoryViewModel?

    private var earlier: [JobHistoryEntry] {
        history?.earlier(excluding: Set(viewModel.rows.map(\.id))) ?? []
    }

    var body: some View {
        Group {
            if viewModel.rows.isEmpty && earlier.isEmpty {
                AppEmptyState(symbol: .activityTab, message: .mobileActivityEmpty)
                    .padding(AppDimensions.Spacing.large)
            } else {
                List {
                    if viewModel.hasActiveJobs {
                        Section(localizer.string(.mobileHistoryActive)) {
                            rows(viewModel.rows.filter(\.canCancel))
                        }
                    }
                    if viewModel.hasFinishedJobs {
                        Section(localizer.string(.mobileHistoryFinished)) {
                            rows(viewModel.rows.filter { !$0.canCancel })
                        }
                    }
                    if let history, !earlier.isEmpty {
                        Section(localizer.string(.mobileHistoryEarlier)) {
                            ForEach(earlier) { entry in
                                MobileHistoryRow(entry: entry, history: history)
                                    .swipeActions {
                                        AppSwipeAction(key: .mobileHistoryDelete, symbol: .clearShelf,
                                                       isDestructive: true) { history.delete(entry.id) }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .appScreenBackground()
        .mobileNavigationBar(.mobileActivityTitle)
        .toolbar {
            if !viewModel.rows.isEmpty || !earlier.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { actionsMenu }
            }
        }
        .accessibilityIdentifier("mobile.jobs")
    }

    private var actionsMenu: some View {
        Menu {
            Button(localizer.string(.jobsClearFinished), systemImage: "trash", action: viewModel.clearFinished)
                .disabled(!viewModel.hasFinishedJobs)
            Button(localizer.string(.jobsCancelAll), systemImage: "xmark.circle", role: .destructive,
                   action: viewModel.cancelAll)
                .disabled(!viewModel.hasActiveJobs)
            if let history {
                Button(localizer.string(.mobileHistoryClearEarlier), systemImage: "clock.badge.xmark",
                       role: .destructive, action: history.clear)
                    .disabled(earlier.isEmpty)
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(localizer.string(.mobileHistoryActions))
    }

    private func rows(_ items: [JobRow]) -> some View {
        ForEach(items) { row in
            MobileActivityRow(
                title: row.operation, detail: row.files, status: row.timeLeft ?? row.status, ring: row.ring,
                preview: viewModel.previewFile(for: row.id),
                onShare: row.canReveal ? { viewModel.reveal(row.id) } : nil,
                onCancel: row.canCancel ? { viewModel.cancel(row.id) } : nil
            )
            .swipeActions {
                if row.canCancel {
                    AppSwipeAction(key: .jobCancel, symbol: .cancelJob, isDestructive: true) {
                        viewModel.cancel(row.id)
                    }
                } else {
                    AppSwipeAction(key: .mobileHistoryDelete, symbol: .clearShelf, isDestructive: true) {
                        viewModel.remove(row.id)
                        history?.delete(row.id)
                    }
                }
            }
        }
    }
}
