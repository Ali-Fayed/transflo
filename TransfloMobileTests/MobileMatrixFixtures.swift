import Foundation
import Testing

private final class MobileFixtureBundle: NSObject {}

/// Bundle resources keep the same bytes available on simulators and physical devices.
enum MobileMatrixFixtures {
    static func file(_ format: String, name: String = "source") throws -> URL {
        let bundle = Bundle(for: MobileFixtureBundle.self)
        return try #require(bundle.url(forResource: name, withExtension: format)
            ?? bundle.url(forResource: name, withExtension: format, subdirectory: "Fixtures"),
                            "Missing source.\(format); run scripts/testing/make-mobile-fixtures.sh")
    }
}
