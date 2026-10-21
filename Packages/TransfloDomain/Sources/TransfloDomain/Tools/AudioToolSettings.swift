/// Loudness targets used by measured two-pass export.
public struct LoudnessSettings: Sendable, Hashable {
    public var integrated: Double
    public var truePeak: Double
    public var range: Double
    public init(integrated: Double = -16, truePeak: Double = -1.5, range: Double = 11) {
        self.integrated = integrated
        self.truePeak = truePeak
        self.range = range
    }
    public var isValid: Bool {
        integrated.isFinite && truePeak.isFinite && range.isFinite
            && (-30 ... -5).contains(integrated) && (-9 ... 0).contains(truePeak) && (1...20).contains(range)
    }
}

public enum ChannelMix: String, Sendable, Hashable, CaseIterable { case mix, left, right }

public struct LoudnessMeasurement: Sendable, Equatable {
    public let integrated: Double
    public let truePeak: Double
    public let range: Double
    public let threshold: Double
    public let offset: Double
    public init(integrated: Double, truePeak: Double, range: Double, threshold: Double, offset: Double) {
        self.integrated = integrated
        self.truePeak = truePeak
        self.range = range
        self.threshold = threshold
        self.offset = offset
    }
    public var isFinite: Bool {
        [integrated, truePeak, range, threshold, offset].allSatisfy(\.isFinite)
    }
}
