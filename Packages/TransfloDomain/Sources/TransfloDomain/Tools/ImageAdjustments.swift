/// Neutral-preserving photo adjustments shared by preview and full-resolution export.
public struct ImageAdjustments: Sendable, Hashable {
    public static let exposureRange = -2.0...2.0
    public static let contrastRange = 0.5...1.5
    public static let saturationRange = 0.0...2.0
    public static let brightnessRange = -0.5...0.5
    public static let unitRange = 0.0...1.0
    public static let signedUnitRange = -1.0...1.0
    public static let neutral = ImageAdjustments(exposure: 0, contrast: 1, saturation: 1)

    public var exposure: Double
    public var contrast: Double
    public var saturation: Double
    public var brightness: Double
    /// Positive values recover highlights or lift shadows.
    public var highlights: Double
    public var shadows: Double
    public var temperature: Double
    public var tint: Double
    public var vibrance: Double
    public var sharpness: Double
    public var noiseReduction: Double
    public var vignette: Double

    public init(
        exposure: Double,
        contrast: Double,
        saturation: Double,
        brightness: Double = 0,
        highlights: Double = 0,
        shadows: Double = 0,
        temperature: Double = 0,
        tint: Double = 0,
        vibrance: Double = 0,
        sharpness: Double = 0,
        noiseReduction: Double = 0,
        vignette: Double = 0
    ) {
        self.exposure = exposure.clamped(to: Self.exposureRange)
        self.contrast = contrast.clamped(to: Self.contrastRange)
        self.saturation = saturation.clamped(to: Self.saturationRange)
        self.brightness = brightness.clamped(to: Self.brightnessRange)
        self.highlights = highlights.clamped(to: Self.unitRange)
        self.shadows = shadows.clamped(to: Self.unitRange)
        self.temperature = temperature.clamped(to: Self.signedUnitRange)
        self.tint = tint.clamped(to: Self.signedUnitRange)
        self.vibrance = vibrance.clamped(to: Self.signedUnitRange)
        self.sharpness = sharpness.clamped(to: Self.unitRange)
        self.noiseReduction = noiseReduction.clamped(to: Self.unitRange)
        self.vignette = vignette.clamped(to: Self.unitRange)
    }

    public var validated: Self {
        Self(exposure: exposure, contrast: contrast, saturation: saturation,
             brightness: brightness, highlights: highlights, shadows: shadows,
             temperature: temperature, tint: tint, vibrance: vibrance,
             sharpness: sharpness, noiseReduction: noiseReduction, vignette: vignette)
    }

    public var isNeutral: Bool { self == .neutral }
}

extension Double {
    /// Invalid numeric input becomes a finite neutral-range value rather than reaching encoders.
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else { return range.contains(0) ? 0 : 1 }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
