import Foundation
import Observation
import os
import TransfloDomain

/// The home screen: brings picked or dropped files into Transflo and opens the wheel for them.
@Observable
final class MobileHomeViewModel {
    /// Everything the home screen renders.
    struct State: Equatable {
        var isImporting = false
        var message: L10nKey?
    }

    private(set) var state = State()
    var isSelectingInput = false
    let inputs: MobileInputCatalog?

    @ObservationIgnored private let importer: any FileImporting
    @ObservationIgnored private let wheel: any KeyboardWheelOpening
    @ObservationIgnored private let provisional: MobileProvisionalImport?
    @ObservationIgnored private let logger = Logger(subsystem: "com.transflo.app", category: "Import")

    init(
        importer: any FileImporting,
        wheel: any KeyboardWheelOpening,
        inputs: MobileInputCatalog? = nil,
        provisional: MobileProvisionalImport? = nil
    ) {
        self.inputs = inputs
        self.provisional = provisional
        self.importer = importer
        self.wheel = wheel
    }

    /// Imports `urls` (copying them can take a while for video), then opens the first wheel with
    /// options for them.
    func receive(_ urls: [URL]) async {
        guard !urls.isEmpty, !state.isImporting else { return }
        if let inputs, !inputs.accepts(urls) {
            state.message = .mobileNoOptions
            return
        }
        state = State(isImporting: true)
        let importer = importer
        let result = await Task.detached { () -> Result<[URL], JobError> in
            do throws(JobError) { return .success(try importer.importFiles(urls)) } catch { return .failure(error) }
        }.value
        state.isImporting = false
        switch result {
        case .success(let copies):
            provisional?.begin(copies)
            if !wheel.openForKeyboard(items: copies, at: WheelPoint(x: 0, y: 0)) {
                provisional?.discard()
                state.message = .mobileNoOptions
            }
        case .failure(let error):
            logger.error("Import failed: \(String(describing: error), privacy: .public)")
            state.message = .mobileImportFailed
        }
    }

    /// Files another app handed over (Open In, Share). "Copy to Transflo" leaves a copy in
    /// Documents/Inbox; once imported it is removed so the inbox doesn't fill up in Files.
    func open(_ urls: [URL]) async {
        await receive(urls)
        for url in urls where MobileInboxCleanup.isSystemInboxCopy(url) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Picking or dropping produced nothing usable (the source app refused, or a photo failed to load).
    func receiveFailed() {
        state.message = .mobileImportFailed
    }

    /// Dismissing the system document picker is an ordinary cancellation, not an import failure.
    func pickerFailed(_ error: any Error) {
        let error = error as NSError
        guard error.domain != NSCocoaErrorDomain || error.code != CocoaError.userCancelled.rawValue else { return }
        receiveFailed()
    }

    /// The wheel and its editor have closed; an import nothing ran on is removed.
    func wheelFlowEnded() {
        provisional?.discard()
    }

    func dismissMessage() {
        state.message = nil
    }
}
