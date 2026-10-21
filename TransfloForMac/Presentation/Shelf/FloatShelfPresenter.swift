import AppKit
import SwiftUI
import TransfloDomain

/// Shows the shelf panel at the right edge of the pointer's screen, sized to its contents, and
/// hides it when the shelf empties (Adapter over `FloatingPanel`).
@MainActor
final class FloatShelfPresenter: FileShelving {
    let viewModel: FloatShelfViewModel
    private let panel: FloatingPanel

    init(viewModel: FloatShelfViewModel = FloatShelfViewModel(), localizer: Localizer) {
        self.viewModel = viewModel
        panel = FloatingPanel(
            size: ShelfLayout.size(itemCount: 0, collapsed: false), identifier: WindowIdentifier.shelf
        )
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: AppLocalizedRoot(localizer: localizer) {
            FloatShelfView(viewModel: viewModel)
        })
        observe()
    }

    func add(_ urls: [URL]) async {
        viewModel.add(urls)
    }

    /// Re-lays the panel whenever the contents or collapse state change.
    private func observe() {
        withObservationTracking {
            layOut()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func layOut() {
        guard !viewModel.isEmpty else {
            panel.orderOut(nil)
            return
        }
        let size = ShelfLayout.size(itemCount: viewModel.items.count, collapsed: viewModel.isCollapsed)
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(origin: .zero, size: size)
        let origin = CGPoint(x: visible.maxX - size.width, y: visible.midY - size.height / 2)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }
}
