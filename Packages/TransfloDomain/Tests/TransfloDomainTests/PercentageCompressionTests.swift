import Foundation
import Testing
import TransfloDomain

struct PercentageCompressionTests {
    @Test("percentage budgets are per file, bounded, and overflow safe")
    func budgets() {
        #expect(CompressionGoal.percentage(50).byteBudget(originalBytes: 2_000_000) == 1_000_000)
        #expect(CompressionGoal.percentage(50).byteBudget(originalBytes: 4_000_000) == 2_000_000)
        #expect(CompressionGoal.percentage(99).byteBudget(originalBytes: Int64.max) != nil)
        #expect(CompressionGoal.percentage(0).byteBudget(originalBytes: 100) == nil)
        #expect(CompressionGoal.percentage(100).byteBudget(originalBytes: 100) == nil)
        #expect(CompressionGoal.percentage(50).byteBudget(originalBytes: 0) == nil)
        #expect(CompressionGoal.percentage(50).byteBudget(originalBytes: -1) == nil)
        #expect(CompressionGoal.medium.byteBudget(originalBytes: 100) == nil)
    }

    @Test("legacy visual customization retains its values when the haptic flag is absent")
    func legacyCustomization() throws {
        let json = #"{"accentHex":"ABCDEF","wheelSize":"large","solidSurfaces":true,"reduceMotion":true}"#
        let value = try JSONDecoder().decode(InterfaceCustomization.self, from: Data(json.utf8))
        #expect(value.accentHex == "ABCDEF" && value.wheelSize == .large)
        #expect(value.solidSurfaces && value.reduceMotion && value.wheelHaptics && value.wheelSound)
        var disabled = value
        disabled.wheelHaptics = false
        disabled.wheelSound = false
        let reopened = try JSONDecoder().decode(InterfaceCustomization.self, from: JSONEncoder().encode(disabled))
        #expect(!reopened.wheelHaptics && !reopened.wheelSound && reopened.accentHex == "ABCDEF")
    }

    @Test("photo adjustment validation contains invalid numeric input")
    func photoValidation() {
        var value = ImageAdjustments.neutral
        value.temperature = .infinity
        value.shadows = -2
        value.brightness = 5
        value.noiseReduction = .nan
        let valid = value.validated
        #expect(valid.temperature == 0 && valid.shadows == 0)
        #expect(valid.brightness == 0.5 && valid.noiseReduction == 0)
    }
}
