import Foundation
import Observation
import TransfloDomain

/// Smart Rename: suggested names for every file, editable before anything is renamed.
@Observable
final class SmartRenameEditorViewModel: ToolEditorModel {
    /// The name being edited for each file, in item order (without extensions).
    var names: [String] = []
    private(set) var isSuggesting = false
    private(set) var error: L10nKey?

    @ObservationIgnored let items: [URL]
    @ObservationIgnored private let suggester: SuggestFileNamesUseCase?

    init(items: [URL], suggester: SuggestFileNamesUseCase?) {
        self.items = items
        self.suggester = suggester
    }

    /// Valid once every name is non-empty after sanitizing and at least one differs from the file's
    /// current name (compared sanitized too, so keeping a name never renames `IMG_1` to `img-1`).
    var settings: ToolSettings? {
        let cleaned = names.map(FileNameSanitizer.sanitize)
        let current = items.map { FileNameSanitizer.sanitize($0.deletingPathExtension().lastPathComponent) }
        guard cleaned.count == items.count, !cleaned.contains(where: \.isEmpty), cleaned != current else {
            return nil
        }
        // A file whose name wasn't changed keeps its exact current name.
        return .renameTo(zip(cleaned, zip(current, items)).map { name, original in
            name == original.0 ? original.1.deletingPathExtension().lastPathComponent : name
        })
    }

    func load() async {
        error = nil
        isSuggesting = true
        defer { isSuggesting = false }
        do {
            guard let suggester, suggester.isAvailable else { throw JobError.unsupported }
            names = try await suggester.execute(for: items)
        } catch {
            names = items.map { $0.deletingPathExtension().lastPathComponent }
            self.error = (error as? JobError).map(JobPresentation.message(for:)) ?? .errorFailed
        }
    }

    /// The file name the edited name produces, extension included.
    func preview(at index: Int) -> String {
        guard names.indices.contains(index), items.indices.contains(index) else { return "" }
        let name = FileNameSanitizer.sanitize(names[index])
        let fileExtension = items[index].pathExtension
        return fileExtension.isEmpty ? name : "\(name).\(fileExtension)"
    }
}
