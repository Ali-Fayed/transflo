import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

struct CompressionTargetTests {
    @Test func qualitySearchApproachesTheBudgetWithoutExceedingIt() throws {
        let encoder = FakeImageEncoder { quality, scale in
            Data(repeating: 1, count: Int((500 + quality * 20_000) * scale * scale))
        }
        let result = try TargetImageCompressionUseCase(encoder: encoder)
            .execute(targetBytes: 10_000, isCancelled: { false })
        #expect((9_000...10_000).contains(result.count))
    }

    @Test func scalesOnlyWhenTheMinimumQualityCannotFit() throws {
        let encoder = FakeImageEncoder(supportsQualitySearch: false) { _, scale in
            Data(repeating: 1, count: Int(20_000 * scale * scale))
        }
        let data = try TargetImageCompressionUseCase(encoder: encoder)
            .execute(targetBytes: 10_000, isCancelled: { false })
        #expect(data.count <= 10_000)
    }

    @Test func impossibleBudgetAndEmptyEncodeFail() {
        let encoder = FakeImageEncoder { _, _ in Data(repeating: 0, count: 100) }
        let search = TargetImageCompressionUseCase(encoder: encoder)
        #expect(throws: JobError.targetUnreachable) { try search.execute(targetBytes: 1, isCancelled: { false }) }
        #expect(throws: JobError.targetUnreachable) { try search.execute(targetBytes: 0, isCancelled: { false }) }
        let empty = TargetImageCompressionUseCase(encoder: FakeImageEncoder { _, _ in Data() })
        #expect(throws: JobError.failed) { try empty.execute(targetBytes: 100, isCancelled: { false }) }
    }

    @Test func cancellationAndEncoderErrorsPropagate() {
        var checks = 0
        let encoder = FakeImageEncoder { quality, _ in Data(repeating: 0, count: Int(quality * 1000 + 10)) }
        #expect(throws: JobError.cancelled) {
            try TargetImageCompressionUseCase(encoder: encoder).execute(targetBytes: 400) {
                checks += 1
                return checks >= 3
            }
        }
        let failing = FakeImageEncoder { _, _ throws(JobError) in throw .unsupported }
        #expect(throws: JobError.unsupported) {
            try TargetImageCompressionUseCase(encoder: failing).execute(targetBytes: 100, isCancelled: { false })
        }
    }

    @Test func mediaBitratesReserveAudioAndRetryWithHeadroom() throws {
        let plan = try #require(MediaTargetBitrate(targetBytes: 1_000_000, duration: 10,
                                                  hasVideo: true, hasAudio: true))
        #expect((plan.video ?? 0) + (plan.audio ?? 0) <= 776_000)
        let retry = try #require(MediaTargetBitrate(targetBytes: 1_000_000, duration: 10,
                                                   hasVideo: true, hasAudio: true, retry: true))
        #expect((retry.video ?? 0) < (plan.video ?? 0))
        let audio = try #require(MediaTargetBitrate(targetBytes: 100_000, duration: 10,
                                                   hasVideo: false, hasAudio: true))
        #expect(audio.video == nil && audio.audio == 77_600)
        for duration in [0, -1, Double.nan, Double.infinity] {
            #expect(MediaTargetBitrate(targetBytes: 100_000, duration: duration,
                                       hasVideo: true, hasAudio: false) == nil)
        }
        #expect(MediaTargetBitrate(targetBytes: 1, duration: 10, hasVideo: true, hasAudio: true) == nil)
        #expect(MediaTargetBitrate(targetBytes: Int64.max, duration: 0.00001,
                                   hasVideo: false, hasAudio: true) == nil)
    }

    @Test func preferencesAreResolvedBeforeQueueingAndPDFKeepsItsExistingFilter() {
        let preferences = InMemoryToolPreferences(goal: .targetBytes(1_000_000))
        let useCase = PrepareWheelJobUseCase(preferences: preferences,
                                             summaries: StubDragSummaryProvider(totalBytes: 100))
        let option = WheelOption(.tool(.compress))
        let jpg = URL(fileURLWithPath: "/tmp/photo.jpg")
        let prepared = useCase.execute(option, items: [jpg])
        #expect(prepared.option.settings == .compress(.targetBytes(1_000_000)))
        #expect(prepared.originalWithinTarget)
        let explicit = WheelOption(.tool(.compress), settings: .compressImage(
            goal: .targetBytes(1_000_000), maximumLongEdge: nil))
        #expect(useCase.execute(explicit, items: [jpg]).originalWithinTarget)
        let resized = WheelOption(.tool(.compress), settings: .compressImage(
            goal: .targetBytes(1_000_000), maximumLongEdge: 1280))
        #expect(!useCase.execute(resized, items: [jpg]).originalWithinTarget)
        let pdf = useCase.execute(option, items: [URL(fileURLWithPath: "/tmp/document.pdf")])
        #expect(pdf.option.settings == .compress(.medium))
        #expect(!pdf.originalWithinTarget)
        #expect(useCase.execute(WheelOption(.action(.copy)), items: [jpg]).option.settings == nil)
        #expect(!useCase.execute(option, items: []).originalWithinTarget)
    }
}
