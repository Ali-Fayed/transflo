import Foundation
import SwiftUI
import Testing
@testable import Transflo
import TransfloDomain

@Suite("Localizer")
struct LocalizerTests {
    @Test("strings resolve in the chosen language")
    func resolvesLanguage() {
        #expect(Localizer(language: .english).string(.settingsLanguage) == "Language")
        #expect(Localizer(language: .arabic).string(.settingsLanguage) == "اللغة")
    }

    @Test("applying a language switches strings, layout direction and locale")
    func switchesLanguage() {
        // Given
        let sut = Localizer(language: .english)
        #expect(sut.layoutDirection == .leftToRight)
        // When
        sut.apply(.arabic)
        // Then
        #expect(sut.language == .arabic)
        #expect(sut.string(.settingsAppearance) == "المظهر")
        #expect(sut.layoutDirection == .rightToLeft)
        #expect(sut.locale.identifier == "ar")
    }

    @Test("format keys fill their arguments in order")
    func formats() {
        let sut = Localizer(language: .english)
        #expect(sut.string(.settingsVersion, arguments: ["1.0", "7"]) == "Version 1.0 (7)")
    }

    @Test("a bundle without the language falls back to the key")
    func missingBundleFallsBack() throws {
        // Given a bundle that has no .lproj folders
        let emptyBundle = try #require(Bundle(path: NSTemporaryDirectory()))
        // When
        let sut = Localizer(language: .arabic, baseBundle: emptyBundle)
        // Then
        #expect(sut.string(.settingsLanguage) == L10nKey.settingsLanguage.rawValue)
    }
}
