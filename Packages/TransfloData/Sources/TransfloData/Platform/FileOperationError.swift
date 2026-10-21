import Foundation
import TransfloDomain

/// Maps Foundation file errors to the job errors the HUD can explain.
enum FileOperationError {
    static func jobError(for error: any Error) -> JobError {
        let nsError = error as NSError
        guard nsError.domain == NSCocoaErrorDomain else { return .failed }
        switch nsError.code {
        case NSFileWriteNoPermissionError, NSFileWriteVolumeReadOnlyError, NSFileWriteOutOfSpaceError:
            return .destinationUnavailable
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
            return .sourceMissing
        default:
            return .failed
        }
    }
}
