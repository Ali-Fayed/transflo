import AppKit
import Observation
import SwiftUI
import TransfloDomain

/// `JobHUDPresenting` Strategy that shows a job where its wheel was: the wheel folds into a disc at
/// its center, which tracks progress and ends in a check or a cross, then fades away.
///
/// Clicking the disc reveals a finished job's outputs; while a job runs, or after it failed, it
/// opens the Jobs window instead. A newer drop replaces the disc.
@Observable
final class JobResultDiscPresenter: JobHUDPresenting {
    private(set) var currentJobID: UUID?
    /// Opens the Jobs window.
    @ObservationIgnored var onShowJobs: (() -> Void)?

    @ObservationIgnored private let panel: FloatingPanel
    @ObservationIgnored private let successDelay: Duration
    @ObservationIgnored private let failureDelay: Duration
    @ObservationIgnored private weak var jobCenter: JobCenter?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private let localizer: Localizer

    /// Room for the disc at its entrance size plus the failure caption beneath it.
    static let panelSize = CGSize(
        width: max(AppDimensions.ResultDisc.diameter * AppDimensions.ResultDisc.enterScale,
                   AppDimensions.ResultDisc.captionWidth),
        height: AppDimensions.ResultDisc.diameter * AppDimensions.ResultDisc.enterScale
            + AppDimensions.ResultDisc.captionHeight + AppDimensions.Spacing.small
    )

    init(localizer: Localizer, successDelay: Duration = .seconds(2.5), failureDelay: Duration = .seconds(5)) {
        panel = FloatingPanel(size: Self.panelSize, identifier: WindowIdentifier.jobResult)
        self.successDelay = successDelay
        self.failureDelay = failureDelay
        self.localizer = localizer
    }

    /// Connects the job center after both are built (they reference each other).
    func attach(to jobCenter: JobCenter) {
        self.jobCenter = jobCenter
        let root = AppLocalizedRoot(localizer: localizer) {
            ResultDiscRoot(presenter: self, jobCenter: jobCenter)
        }
        panel.contentView = NSHostingView(rootView: root)
    }

    func present(_ jobID: UUID) {
        hideTask?.cancel()
        currentJobID = jobID
        guard let origin = jobCenter?.job(jobID)?.origin else { return }
        // The disc's center sits on the job's origin: the center of the wheel it was dropped on.
        let size = Self.panelSize
        let discTop = AppDimensions.ResultDisc.diameter * AppDimensions.ResultDisc.enterScale / 2
        let anchor = CGPoint(x: origin.x, y: origin.y)
        panel.place(origin: CGPoint(x: anchor.x - size.width / 2, y: anchor.y + discTop - size.height),
                    anchor: anchor)
    }

    func jobFinished(_ jobID: UUID) {
        guard jobID == currentJobID, let state = jobCenter?.job(jobID)?.state else { return }
        let delay = if case .succeeded = state { successDelay } else { failureDelay }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, self?.currentJobID == jobID else { return }
            self?.hide()
        }
    }

    /// Reveals a successful job's files; otherwise opens Jobs, where progress and errors are listed.
    func handleTap() {
        guard let jobID = currentJobID, let state = jobCenter?.job(jobID)?.state else {
            hide()
            return
        }
        if case .succeeded = state {
            jobCenter?.reveal(jobID)
            hide()
        } else {
            onShowJobs?()
        }
    }

    private func hide() {
        hideTask?.cancel()
        panel.orderOut(nil)
        currentJobID = nil
    }
}

/// Observes the presenter so a new drop replaces the disc (and restarts its entrance).
private struct ResultDiscRoot: View {
    @Environment(Localizer.self) private var localizer
    let presenter: JobResultDiscPresenter
    let jobCenter: JobCenter

    var body: some View {
        VStack {
            if let jobID = presenter.currentJobID, let record = jobCenter.job(jobID) {
                AppResultDisc(status: JobPresentation.ring(for: record.state), caption: caption(for: record.state))
                    .onTapGesture(perform: presenter.handleTap)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label(for: record))
                    .accessibilityAddTraits(.isButton)
                    .id(jobID)
            }
            Spacer(minLength: .zero)
        }
        .padding(.top, AppDimensions.ResultDisc.diameter * (AppDimensions.ResultDisc.enterScale - 1) / 2)
        .frame(width: JobResultDiscPresenter.panelSize.width, height: JobResultDiscPresenter.panelSize.height)
    }

    private func caption(for state: JobState) -> L10nKey? {
        guard case .failed(let error) = state, error != .cancelled else { return nil }
        return JobPresentation.message(for: error)
    }

    /// Title, then the failure reason when there is one, then the file name.
    private func label(for record: JobRecord) -> String {
        let title = JobPresentation.title(for: record)
        let reason = caption(for: record.state).map { localizer.string($0) }
        let name = record.items.first?.lastPathComponent
        return [localizer.string(title.key, arguments: title.arguments), reason, name]
            .compactMap { $0 }.joined(separator: ", ")
    }
}
