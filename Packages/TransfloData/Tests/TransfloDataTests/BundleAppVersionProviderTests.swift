import Foundation
import Testing
import TransfloData
import TransfloDomain

@Suite("System providers")
struct BundleAppVersionProviderTests {
    @Test("version and build come from Info.plist keys")
    func readsKeys() {
        let sut = BundleAppVersionProvider(infoDictionary: [
            "CFBundleShortVersionString": "1.4",
            "CFBundleVersion": "88"
        ])
        #expect(sut.current == AppVersion(marketing: "1.4", build: "88"))
    }

    @Test("missing or mistyped keys fall back to zeros")
    func fallbacks() {
        #expect(BundleAppVersionProvider(infoDictionary: nil).current == AppVersion(marketing: "0.0.0", build: "0"))
        let mistyped = BundleAppVersionProvider(infoDictionary: [
            "CFBundleShortVersionString": 3,
            "CFBundleVersion": true
        ])
        #expect(mistyped.current == AppVersion(marketing: "0.0.0", build: "0"))
    }

    @Test("preferred languages mirror the system list")
    func preferredLanguages() {
        #expect(SystemPreferredLanguagesProvider().preferredLanguageCodes == Locale.preferredLanguages)
    }
}
