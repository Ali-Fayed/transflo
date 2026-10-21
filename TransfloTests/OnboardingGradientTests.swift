import SwiftUI
import Testing
@testable import Transflo
import TransfloDomain

@Suite("Onboarding gradient")
struct OnboardingGradientTests {
    @Test("the default accent keeps the designed pair from the asset catalog")
    func defaultAccent() {
        let gradient = AppColors.onboardingGradient(accentHex: nil)
        #expect(gradient.start == Color(.onboardingStart))
        #expect(gradient.end == Color(.onboardingEnd))
    }

    @Test("a chosen accent tints the canvas, stronger at the start than the end")
    func chosenAccent() {
        let gradient = AppColors.onboardingGradient(accentHex: "7C3AED")
        let accent = AppColors.color(hex: "7C3AED")
        #expect(gradient.start == accent.opacity(0.28))
        #expect(gradient.end == accent.opacity(0.08))
        #expect(gradient.start != Color(.onboardingStart))
    }

    @Test("different accents give different canvases")
    func distinctAccents() {
        let violet = AppColors.onboardingGradient(accentHex: "7C3AED")
        let orange = AppColors.onboardingGradient(accentHex: "EA580C")
        #expect(violet.start != orange.start)
        #expect(violet.end != orange.end)
    }

    @Test("an invalid stored accent is validated away, keeping the designed pair")
    func malformedAccent() {
        let stored = InterfaceCustomization(accentHex: "not-a-color")
        let gradient = AppColors.onboardingGradient(accentHex: stored.accentHex)
        #expect(gradient.start == Color(.onboardingStart))
        #expect(gradient.end == Color(.onboardingEnd))
    }
}
