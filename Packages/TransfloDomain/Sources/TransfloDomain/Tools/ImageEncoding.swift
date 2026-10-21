import Foundation

/// Strategy for one candidate image encode. Scale is relative to the source's pixel dimensions.
public protocol ImageEncoding {
    var supportsQualitySearch: Bool { get }
    func encode(quality: Double, scale: Double) throws(JobError) -> Data
}
