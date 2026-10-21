import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

struct TargetCompressionTests {
    @Test func imageSearchWritesAReadableFileWithinBudget() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("noise.jpg")
        try ImageFileWriter(ffmpeg: nil).write(try image(), format: "jpg", quality: 0.99, to: source)
        let size = try #require(source.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let target = Int64(size / 2)
        let output = folder.url.appendingPathComponent("result.jpg")
        try TargetImageCompressor.compress(source, budget: ("jpg", target), writer: ImageFileWriter(ffmpeg: nil),
                                           to: output, isCancelled: { false })
        #expect(try Data(contentsOf: output).count <= target)
        #expect(try ImageDecoding.decodeUpright(output).image.width > 0)
    }

    @Test func smallOriginalIsCopiedExactlyAndFailuresLeaveNoOutput() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("source.jpg")
        try ImageFileWriter(ffmpeg: nil).write(try image(), format: "jpg", to: source)
        let output = folder.url.appendingPathComponent("result.jpg")
        let original = try Data(contentsOf: source)
        try TargetImageCompressor.compress(source, budget: ("jpg", Int64(original.count + 1)),
                                           writer: ImageFileWriter(ffmpeg: nil), to: output, isCancelled: { false })
        #expect(try Data(contentsOf: output) == original)
        try FileManager.default.removeItem(at: output)
        #expect(throws: JobError.targetUnreachable) {
            try TargetImageCompressor.compress(source, budget: ("jpg", 1), writer: ImageFileWriter(ffmpeg: nil),
                                               to: output, isCancelled: { false })
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
        var checks = 0
        #expect(throws: JobError.cancelled) {
            try TargetImageCompressor.compress(source, budget: ("jpg", Int64(original.count / 2)),
                                               writer: ImageFileWriter(ffmpeg: nil), to: output) {
                checks += 1
                return checks > 2
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path) == ["source.jpg"])
    }

    @Test func publicationNeverDeletesOrReplacesACompetingFile() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let staged = folder.url.appendingPathComponent("staged")
        let output = folder.url.appendingPathComponent("output")
        try Data([1]).write(to: staged)
        try Data([2]).write(to: output)
        #expect(throws: JobError.destinationOccupied) {
            try ToolOutputPublisher.publish(staged, to: output, isCancelled: { false })
        }
        #expect(try Data(contentsOf: output) == Data([2]))
        #expect(throws: JobError.cancelled) {
            try ToolOutputPublisher.publish(staged, to: output, isCancelled: { true })
        }
    }

    @Test func toolDefaultsRoundTripAndRejectCorruptStorage() throws {
        let name = "transflo-target-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        #expect(repository.loadCompressionGoal() == .medium)
        #expect(repository.loadNameStyle() == .parentheses)
        for goal: CompressionGoal in [.light, .medium, .strong] {
            repository.saveCompressionGoal(goal)
            #expect(repository.loadCompressionGoal() == goal)
        }
        repository.saveNameStyle(.word)
        #expect(repository.loadNameStyle() == .word)
        for goal: CompressionGoal in [.targetBytes(1_500_000), .percentage(35)] {
            repository.saveCompressionGoal(goal)
            #expect(repository.loadCompressionGoal() == .medium)
        }
        repository.saveCompressionGoal(.targetBytes(-1))
        #expect(repository.loadCompressionGoal() == .medium)
        defaults.set(Data("invalid".utf8), forKey: SettingsStorageKey.compressionGoal)
        #expect(repository.loadCompressionGoal() == .medium)
    }

    @Test func missingAndCorruptImagesAreRejectedWithoutPublishing() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("bad.jpg")
        let output = folder.url.appendingPathComponent("output.jpg")
        #expect(throws: JobError.sourceMissing) {
            try TargetImageCompressor.compress(source, budget: ("jpg", 100_000), writer: ImageFileWriter(ffmpeg: nil),
                                               to: output, isCancelled: { false })
        }
        try Data("not an image".utf8).write(to: source)
        #expect(throws: JobError.self) {
            try TargetImageCompressor.compress(source, budget: ("jpg", 100_000), writer: ImageFileWriter(ffmpeg: nil),
                                               to: output, isCancelled: { false })
        }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    private func image() throws -> CGImage {
        let size = 256
        var seed: UInt32 = 1
        let bytes = (0..<(size * size * 4)).map { index -> UInt8 in
            if index % 4 == 3 { return 255 }
            seed = seed &* 1_664_525 &+ 1_013_904_223
            return UInt8(truncatingIfNeeded: seed >> 16)
        }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }
}
