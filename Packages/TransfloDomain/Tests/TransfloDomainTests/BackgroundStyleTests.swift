import Testing
import TransfloDomain

struct BackgroundStyleTests {
    @Test func clampsInvalidSettingsAndPreservesCanvasRatios() {
        let style = BackgroundStyle(fill: .solid("invalid"), padding: .nan, corners: -1, shadow: 1000)
        #expect(style.fill == .solid("#FFFFFF"))
        #expect(style.padding == 0 && style.corners == 0 && style.shadow == 100)
        let padded = BackgroundStyle(padding: 0.1).canvasDimensions(imageWidth: 100, imageHeight: 50)
        #expect(padded.width == 110 && padded.height == 60)
        for ratio in BackgroundCanvasRatio.allCases {
            let size = BackgroundStyle(padding: 0.1, ratio: ratio).canvasDimensions(imageWidth: 100, imageHeight: 50)
            #expect(size.width >= 110 && size.height >= 60)
            if let expected = ratio.ratio { #expect(abs(size.width / size.height - expected) < 0.02) }
        }
        #expect(style.canvasDimensions(imageWidth: 0, imageHeight: 100).width == 0)
        #expect(BackgroundPreset.allCases.count == 8)
        #expect(Set(BackgroundPreset.allCases.map(\.colors.start)).count == 8)
    }
}
