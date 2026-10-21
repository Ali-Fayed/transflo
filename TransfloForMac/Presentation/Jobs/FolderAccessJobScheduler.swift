import Foundation
import TransfloDomain

/// Decorator for the sandboxed App Store edition: before a job that writes beside the dropped files
/// runs, it makes sure Transflo may write in their folders, asking once per folder. If the user
/// declines, the job isn't scheduled and a hint explains why.
final class FolderAccessJobScheduler: JobScheduling {
    private let base: any JobScheduling
    private let access: any FolderAccessProviding
    private let hints: any HintPresenting

    init(base: any JobScheduling, access: any FolderAccessProviding, hints: any HintPresenting) {
        self.base = base
        self.access = access
        self.hints = hints
    }

    func schedule(_ option: WheelOption, items: [URL], near point: WheelPoint) {
        var missing = Self.writesBesideOriginals(option) ? access.granted.missing(for: items) : []
        if case .action(.move) = option.kind, case .destination(let folder) = option.settings,
           !access.granted.covers(folder),
           !missing.contains(where: { $0.standardizedFileURL.path == folder.standardizedFileURL.path }) {
            missing.append(folder)
        }
        guard !missing.isEmpty else {
            base.schedule(option, items: items, near: point)
            return
        }
        Task { @MainActor [base, access, hints] in
            for folder in missing where !access.granted.covers(folder) {
                guard await access.requestAccess(to: folder) else {
                    hints.showHint(.folderAccessDenied, near: point)
                    return
                }
            }
            base.schedule(option, items: items, near: point)
        }
    }

    /// Conversions and tools save next to the original, and Move removes it from its folder.
    /// The other actions only read the files or hand them to the system.
    static func writesBesideOriginals(_ option: WheelOption) -> Bool {
        switch option.kind {
        case .format, .tool, .recipe, .action(.move), .action(.archive): true
        case .action: false
        }
    }
}
