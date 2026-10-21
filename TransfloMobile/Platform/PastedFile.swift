import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Something copied in another app — a file, a photo, a PDF or plain text — received as a file.
/// Representations are tried in order, so a copied photo arrives as an image rather than raw data.
struct PastedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie, importing: received)
        FileRepresentation(importedContentType: .image, importing: received)
        FileRepresentation(importedContentType: .pdf, importing: received)
        FileRepresentation(importedContentType: .audio, importing: received)
        FileRepresentation(importedContentType: .plainText, importing: received)
        FileRepresentation(importedContentType: .data, importing: received)
    }

    private static func received(_ file: ReceivedTransferredFile) throws -> PastedFile {
        guard let staged = ItemProviderFileLoader.stage(file.file, named: nil) else {
            throw CocoaError(.fileReadUnknown)
        }
        return PastedFile(url: staged)
    }
}
