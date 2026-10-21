import CoreGraphics
import Testing
import TransfloDomain

@Suite("Assembly settings")
struct AssemblySettingsTests {
    @Test("paper sizes are in points, and landscape swaps only fixed paper")
    func pageSizes() {
        let photo = CGSize(width: 4000, height: 3000)
        #expect(AssemblySettings(order: [0], paper: .original, landscape: true).pageSize(original: photo) == photo)
        let letter = AssemblySettings(order: [0], paper: .letter)
        #expect(letter.pageSize(original: photo) == CGSize(width: 612, height: 792))
        #expect(AssemblySettings(order: [0], paper: .letter, landscape: true).pageSize(original: photo)
            == CGSize(width: 792, height: 612))
        let aFour = AssemblySettings(order: [0], paper: .aFour).pageSize(original: photo)
        #expect(abs(aFour.width - 595.276) < 0.001 && abs(aFour.height - 841.89) < 0.001)
    }

    @Test("fit keeps the whole image inside the margins and centers it")
    func fit() {
        let sut = AssemblySettings(order: [0], margin: 50)
        let frame = sut.imageFrame(image: CGSize(width: 200, height: 100), page: CGSize(width: 500, height: 500))
        #expect(frame == CGRect(x: 50, y: 150, width: 400, height: 200))
    }

    @Test("fill covers the content box, cropping the long side")
    func fill() {
        let sut = AssemblySettings(order: [0], margin: 0, fill: true)
        let frame = sut.imageFrame(image: CGSize(width: 200, height: 100), page: CGSize(width: 500, height: 500))
        #expect(frame == CGRect(x: -250, y: 0, width: 1000, height: 500))
    }

    @Test("margins are clamped to a third of the page, and empty images get no frame")
    func edgeCases() {
        let page = CGSize(width: 300, height: 300)
        let huge = AssemblySettings(order: [0], margin: 10_000)
        #expect(huge.imageFrame(image: CGSize(width: 10, height: 10), page: page)
            == CGRect(x: 100, y: 100, width: 100, height: 100))
        let negative = AssemblySettings(order: [0], margin: -40)
        #expect(negative.imageFrame(image: CGSize(width: 10, height: 10), page: page)
            == CGRect(origin: .zero, size: page))
        #expect(AssemblySettings(order: [0]).imageFrame(image: .zero, page: page) == .zero)
    }

    @Test("order follows the user's arrangement of the original drop")
    func ordering() {
        #expect(AssemblySettings(order: [2, 0, 1]).ordered(["a", "b", "c"]) == ["c", "a", "b"])
        #expect(AssemblySettings(order: [1]).ordered(["a", "b"], minimum: 1) == ["b"])
    }

    @Test("invalid orders and margins are refused rather than guessed",
          arguments: [
              AssemblySettings(order: [0]),
              AssemblySettings(order: [0, 0]),
              AssemblySettings(order: [0, 3]),
              AssemblySettings(order: [-1, 0]),
              AssemblySettings(order: [0, 1], margin: 145),
              AssemblySettings(order: [0, 1], margin: -1),
              AssemblySettings(order: [0, 1], margin: .nan)
          ])
    func rejects(settings: AssemblySettings) {
        #expect(settings.ordered(["a", "b", "c"]) == nil)
    }
}

@Suite("Loudness settings")
struct LoudnessSettingsTests {
    @Test("the defaults are a valid broadcast-style target")
    func defaults() {
        #expect(LoudnessSettings().isValid)
        #expect(LoudnessSettings(integrated: -30, truePeak: -9, range: 1).isValid)
        #expect(LoudnessSettings(integrated: -5, truePeak: 0, range: 20).isValid)
    }

    @Test("targets outside ffmpeg's loudnorm ranges are invalid",
          arguments: [
              LoudnessSettings(integrated: -31), LoudnessSettings(integrated: -4),
              LoudnessSettings(truePeak: 0.5), LoudnessSettings(truePeak: -10),
              LoudnessSettings(range: 0.5), LoudnessSettings(range: 21),
              LoudnessSettings(integrated: .nan), LoudnessSettings(range: .infinity)
          ])
    func invalid(settings: LoudnessSettings) {
        #expect(!settings.isValid)
    }

    @Test("a measurement of digital silence is not finite")
    func silence() {
        #expect(LoudnessMeasurement(integrated: -20, truePeak: -2, range: 5, threshold: -30, offset: 0.4).isFinite)
        #expect(!LoudnessMeasurement(integrated: -.infinity, truePeak: -2, range: 5, threshold: -30, offset: 0)
            .isFinite)
    }
}
