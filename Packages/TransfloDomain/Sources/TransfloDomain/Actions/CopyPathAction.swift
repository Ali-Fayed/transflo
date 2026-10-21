import Foundation

/// Copy Path: POSIX paths on the clipboard; with ⌥ held, paths in the home folder use `~`.
public struct CopyPathAction: FileActionPerforming {
    private let copier: any TextCopying
    private let modifiers: any ModifierStateReading
    private let home: URL?

    public init(copier: any TextCopying, modifiers: any ModifierStateReading, home: URL?) {
        self.copier = copier
        self.modifiers = modifiers
        self.home = home
    }

    public func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL] {
        copier.copy(CopyPathFormatter.text(for: items, home: home, abbreviatingHome: modifiers.isOptionPressed))
        return []
    }
}
