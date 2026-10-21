import AppKit
import Observation
import SwiftUI
import TransfloDomain

/// `HintPresenting` backed by a small floating card next to the pointer, for messages that aren't
/// jobs (for example, nothing selected in Finder). Jobs show in the wheel's result disc instead.
@Observable
final class HintHUDPresenter: HintPresenting {
    private(set) var hint: L10nKey?

    @ObservationIgnored private let panel: FloatingPanel
    @ObservationIgnored private let visibleFor: Duration
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    init(localizer: Localizer, visibleFor: Duration = .seconds(5)) {
        let size = CGSize(
            width: AppDimensions.HUD.width + AppDimensions.Wheel.margin * 2,
            height: AppDimensions.HUD.height + AppDimensions.Wheel.margin * 2
        )
        panel = FloatingPanel(size: size, identifier: WindowIdentifier.hint)
        self.visibleFor = visibleFor
        panel.contentView = NSHostingView(rootView: AppLocalizedRoot(localizer: localizer) {
            HintRoot(presenter: self)
        })
    }

    func showHint(_ message: L10nKey, near point: WheelPoint) {
        hideTask?.cancel()
        hint = message
        let offset = AppDimensions.HUD.offset
        let anchor = CGPoint(x: point.x, y: point.y)
        panel.place(origin: CGPoint(x: anchor.x + offset, y: anchor.y - offset - panel.frame.height), anchor: anchor)
        hideTask = Task { [weak self, visibleFor] in
            try? await Task.sleep(for: visibleFor)
            guard !Task.isCancelled, self?.hint == message else { return }
            self?.hide()
        }
    }

    fileprivate func hide() {
        hideTask?.cancel()
        panel.orderOut(nil)
        hint = nil
    }
}

/// Observes the presenter so a newer hint replaces the shown one.
private struct HintRoot: View {
    let presenter: HintHUDPresenter

    var body: some View {
        if let hint = presenter.hint {
            AppHUDCard(onTap: presenter.hide) {
                AppIcon(symbol: .hint, size: AppDimensions.IconSize.medium)
                    .foregroundStyle(AppColors.accent)
            } text: {
                AppText(hint, style: .headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
