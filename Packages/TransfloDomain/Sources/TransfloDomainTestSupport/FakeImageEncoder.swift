import Foundation
import TransfloDomain

/// Configurable encoding Strategy for bounded searches, errors and cancellation tests.
public struct FakeImageEncoder: ImageEncoding {
    public let supportsQualitySearch: Bool
    private let encodeCandidate: (Double, Double) throws(JobError) -> Data

    public init(
        supportsQualitySearch: Bool = true,
        encode: @escaping (Double, Double) throws(JobError) -> Data
    ) {
        self.supportsQualitySearch = supportsQualitySearch
        self.encodeCandidate = encode
    }

    public func encode(quality: Double, scale: Double) throws(JobError) -> Data {
        try encodeCandidate(quality, scale)
    }
}
