import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("File error mapping")
struct FileOperationErrorTests {
    @Test("Cocoa errors map to job errors", arguments: [
        (NSFileWriteNoPermissionError, JobError.destinationUnavailable),
        (NSFileWriteVolumeReadOnlyError, .destinationUnavailable),
        (NSFileWriteOutOfSpaceError, .destinationUnavailable),
        (NSFileReadNoSuchFileError, .sourceMissing),
        (NSFileNoSuchFileError, .sourceMissing),
        (NSFileWriteUnknownError, .failed)
    ])
    func errorMapping(code: Int, expected: JobError) {
        let error = NSError(domain: NSCocoaErrorDomain, code: code)
        #expect(FileOperationError.jobError(for: error) == expected)
    }

    @Test("non-Cocoa errors map to failed")
    func foreignError() {
        #expect(FileOperationError.jobError(for: NSError(domain: NSPOSIXErrorDomain, code: 1)) == .failed)
    }
}
