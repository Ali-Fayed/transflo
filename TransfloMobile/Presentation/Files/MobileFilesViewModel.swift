import Foundation
import Observation
import os
import TransfloDomain

/// The Files tab: every import and its results, newest first, with Convert (the wheel), Quick Look,
/// Share and Delete for one file or a selection.
@Observable
final class MobileFilesViewModel {
    private(set) var folders: [WorkspaceFolder] = []
    var selection: Set<URL> = []
    /// The file open in Quick Look.
    var previewing: URL?
    private(set) var message: L10nKey?

    @ObservationIgnored private let workspace: any WorkspaceBrowsing
    @ObservationIgnored private let wheel: any KeyboardWheelOpening
    @ObservationIgnored private let share: ([URL]) -> Void
    @ObservationIgnored private let logger = Logger(subsystem: "com.transflo.app", category: "Files")

    init(workspace: any WorkspaceBrowsing, wheel: any KeyboardWheelOpening, share: @escaping ([URL]) -> Void) {
        self.workspace = workspace
        self.wheel = wheel
        self.share = share
    }

    var isEmpty: Bool { folders.isEmpty }

    func reload() async {
        let workspace = workspace
        let result = await Task.detached { () -> Result<[WorkspaceFolder], JobError> in
            do throws(JobError) { return .success(try workspace.folders()) } catch { return .failure(error) }
        }.value
        switch result {
        case .success(let folders):
            self.folders = folders
            let present = Set(folders.flatMap { $0.files.map(\.url) })
            selection.formIntersection(present)
        case .failure(let error):
            logger.error("Workspace unreadable: \(String(describing: error), privacy: .public)")
            message = .mobileFilesUnreadable
        }
    }

    /// Opens the wheel for `urls`; files nothing can handle say so.
    func convert(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        message = wheel.openForKeyboard(items: urls, at: WheelPoint(x: 0, y: 0)) ? nil : .mobileNoOptions
    }

    func shareFiles(_ urls: [URL]) {
        share(urls)
    }

    func preview(_ url: URL) {
        previewing = url
    }

    func delete(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        do throws(JobError) {
            try workspace.delete(urls)
            message = nil
        } catch {
            logger.error("Delete failed: \(String(describing: error), privacy: .public)")
            message = .mobileDeleteFailed
        }
        selection.subtract(urls)
        await reload()
    }

    func dismissMessage() {
        message = nil
    }
}
