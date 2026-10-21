import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The share extension's entry point: hosts the session screen and ends the request when it's done.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private lazy var session = ShareSession(
        container: MobileContainer(documents: FileManager.default.temporaryDirectory
            .appendingPathComponent("TransfloShare", isDirectory: true)),
        onFinish: { [weak self] in self?.finish() }
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        let session = session
        let root = AppLocalizedRoot(localizer: session.container.localizer) {
            ShareSessionView(session: session)
        }
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        Task { await session.receive(providers) }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
