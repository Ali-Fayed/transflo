/// Pure bitrate budgeting shared by media planning and deterministic tests.
public struct MediaTargetBitrate: Equatable, Sendable {
    public let video: Int?
    public let audio: Int?

    public init?(targetBytes: Int64, duration: Double, hasVideo: Bool, hasAudio: Bool, retry: Bool = false) {
        guard targetBytes > 0, duration.isFinite, duration > 0, hasVideo || hasAudio else { return nil }
        let budget = Double(targetBytes) * 8 / duration * 0.97 * (retry ? 0.9 : 1)
        guard budget.isFinite, budget >= 16_000, budget < Double(Int.max) else { return nil }
        let audioBudget = hasAudio ? (hasVideo ? min(96_000, max(16_000, budget * 0.15)) : budget) : 0
        let videoBudget = hasVideo ? budget - audioBudget : 0
        guard !hasVideo || videoBudget >= 32_000 else { return nil }
        self.video = hasVideo ? Int(videoBudget) : nil
        self.audio = hasAudio ? Int(audioBudget) : nil
    }
}
