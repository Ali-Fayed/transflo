import AppIntents
import Foundation
import TransfloDomain

/// Converts between Shortcuts files and the files Transflo works on.
nonisolated enum IntentFiles {
    static func inputs(_ files: [IntentFile]) -> [(name: String, data: Data)] {
        files.map { ($0.filename, $0.data) }
    }

    static func outputs(_ urls: [URL]) -> [IntentFile] {
        urls.map {
            var file = IntentFile(fileURL: $0, filename: $0.lastPathComponent)
            file.removedOnCompletion = true
            return file
        }
    }

    /// A job error as a message Shortcuts can show.
    @MainActor static func failure(_ error: JobError) -> IntentFailure {
        IntentFailure(message: LocalizedStringResource(stringLiteral: JobPresentation.message(for: error).rawValue))
    }
}

/// An error whose message Shortcuts shows to the user.
nonisolated struct IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    let message: LocalizedStringResource
    var localizedStringResource: LocalizedStringResource { message }
}
