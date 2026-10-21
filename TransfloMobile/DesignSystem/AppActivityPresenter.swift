import SwiftUI
import UIKit

/// Presents the system share sheet straight from the screen beneath, with no empty SwiftUI sheet
/// hosting it, and reports once when it closes.
struct AppActivityPresenter: UIViewControllerRepresentable {
    let urls: [URL]?
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> HostController { HostController() }

    func updateUIViewController(_ host: HostController, context: Context) {
        host.onFinish = onFinish
        host.show(urls)
    }

    final class HostController: UIViewController {
        var onFinish: () -> Void = {}
        private var shown: [URL]?

        func show(_ urls: [URL]?) {
            guard urls != shown else { return }
            shown = urls
            guard let urls else { return }
            DispatchQueue.main.async { [weak self] in self?.present(urls) }
        }

        private func present(_ urls: [URL]) {
            guard shown == urls, view.window != nil else { return }
            let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            activity.popoverPresentationController?.sourceView = view
            activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY,
                                                                       width: 1, height: 1)
            activity.completionWithItemsHandler = { [weak self] _, _, _, _ in
                self?.shown = nil
                self?.onFinish()
            }
            topmost.present(activity, animated: true)
        }

        private var topmost: UIViewController {
            var top: UIViewController = self
            while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
            return top
        }
    }
}
