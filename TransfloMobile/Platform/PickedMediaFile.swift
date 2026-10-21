import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A photo or video picked from the library, received as its original file.
struct PickedMediaFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie, importing: received)
        FileRepresentation(importedContentType: .image, importing: received)
    }

    private static func received(_ file: ReceivedTransferredFile) throws -> PickedMediaFile {
        guard let staged = ItemProviderFileLoader.stage(file.file, named: nil) else {
            throw CocoaError(.fileReadUnknown)
        }
        return PickedMediaFile(url: staged)
    }
}
