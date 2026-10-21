import Foundation
import TransfloDomain

/// The clipboard's files, or a copied image saved as a file, for Convert Clipboard.
protocol ClipboardFilesReading {
    /// Empty when the clipboard holds no files or image.
    func files() throws(JobError) -> [URL]
}
