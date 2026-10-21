import Testing
import TransfloDomain

@Suite("Tool geometry and adjustments")
struct ToolGeometryTests {
    @Test("normalized rects clamp inside the unit square with a minimum size")
    func clamps() {
        let shifted = NormalizedRect(x: -0.2, y: 0.9, width: 0.5, height: 0.5)
        #expect(shifted == NormalizedRect(x: 0, y: 0.5, width: 0.5, height: 0.5))
        #expect(NormalizedRect(x: 0, y: 0, width: 0, height: 2).width == 0.01)
        #expect(NormalizedRect(x: 0, y: 0, width: 0, height: 2).height == 1)
    }

    @Test("pixel rects round to whole pixels and stay inside the image")
    func pixels() {
        let rect = NormalizedRect(x: 0.25, y: 0.5, width: 0.5, height: 0.5)
        #expect(rect.pixels(width: 64, height: 48) == PixelRect(x: 16, y: 24, width: 32, height: 24))
        let even = NormalizedRect.full.pixels(width: 101, height: 51, even: true)
        #expect(even == PixelRect(x: 0, y: 0, width: 100, height: 50))
        let tiny = NormalizedRect(x: 0.99, y: 0.99, width: 0.01, height: 0.01)
        #expect(tiny.pixels(width: 10, height: 10, even: true) == PixelRect(x: 8, y: 8, width: 2, height: 2))
    }

    @Test("adjustments clamp to their ranges")
    func adjustments() {
        let wild = ImageAdjustments(exposure: 9, contrast: 0, saturation: -1)
        #expect(wild == ImageAdjustments(exposure: 2, contrast: 0.5, saturation: 0))
        #expect(ImageAdjustments.neutral.isNeutral)
        #expect(!wild.isNeutral)
    }

    @Test("interactive tools have no instant defaults")
    func interactiveDefaults() {
        for tool in [ToolKind.crop, .resize, .adjust, .trim, .changeSpeed, .split, .snapshot] {
            #expect(ToolSettings.defaults(for: tool) == .none)
        }
        #expect(ToolPreview.empty.thumbnail == nil)
    }
}
