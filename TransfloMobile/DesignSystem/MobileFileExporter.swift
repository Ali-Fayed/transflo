import SwiftUI
import UIKit

/// Presents the Files controller modally, giving its remote browser a real presentation lifecycle.
struct MobileFileExporter: UIViewControllerRepresentable {
    let urls: [URL]
    let onFinish: (Bool) -> Void

    func makeUIViewController(context: Context) -> ExportHostController {
        ExportHostController(urls: urls, onFinish: onFinish)
    }

    func updateUIViewController(_ controller: ExportHostController, context: Context) {}

    final class ExportHostController: UIViewController, UIDocumentPickerDelegate,
                                      UIAdaptivePresentationControllerDelegate {
        private let urls: [URL]
        private let onFinish: (Bool) -> Void
        private var started = false
        private var finished = false

        init(urls: [URL], onFinish: @escaping (Bool) -> Void) {
            self.urls = urls
            self.onFinish = onFinish
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !started else { return }
            started = true
            let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
            picker.delegate = self
            picker.directoryURL = .documentsDirectory
            present(picker, animated: true) { picker.presentationController?.delegate = self }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish(false, controller: controller)
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finish(true, controller: controller)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard !finished else { return }
            finished = true
            onFinish(false)
        }

        private func finish(_ saved: Bool, controller: UIDocumentPickerViewController) {
            guard !finished else { return }
            finished = true
            controller.dismiss(animated: true) { [onFinish] in onFinish(saved) }
        }
    }
}
