import CoreGraphics
import Foundation
import TransfloDomain

/// Bounds a single decoded RGBA surface to 256 MB before integer conversion or allocation.
enum RasterLimits {
    static func allows(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite
            && size.width >= 1 && size.height >= 1
            && size.width <= 32_768 && size.height <= 32_768
            && size.width * size.height <= 64_000_000
    }

    /// Releases framework temporaries between pages without erasing the typed job error.
    static func withPool<Value>(_ body: () throws(JobError) -> Value) throws(JobError) -> Value {
        let result: Result<Value, JobError> = autoreleasepool {
            do throws(JobError) { return .success(try body()) } catch { return .failure(error) }
        }
        return try result.get()
    }
}
