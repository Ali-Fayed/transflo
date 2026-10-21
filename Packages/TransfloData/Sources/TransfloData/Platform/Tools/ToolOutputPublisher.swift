import Darwin
import Foundation
import TransfloDomain

/// Same-volume, atomic, no-replace publication, including directory outputs.
enum ToolOutputPublisher {
    static func publish(_ staged: URL, to output: URL, isCancelled: () -> Bool) throws(JobError) {
        if isCancelled() { throw .cancelled }
        try OutputProvenance.shared.publishing(output) { () throws(JobError) in
            let result = staged.path.withCString { source in
                output.path.withCString { destination in renamex_np(source, destination, UInt32(RENAME_EXCL)) }
            }
            guard result == 0 else { throw errno == EEXIST ? .destinationOccupied : .destinationUnavailable }
        }
    }
}
