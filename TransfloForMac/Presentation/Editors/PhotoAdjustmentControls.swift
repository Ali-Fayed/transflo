import TransfloDomain

/// Slider metadata keeps labels, ranges, and per-control neutral values together.
struct PhotoAdjustmentControl: Identifiable {
    let label: L10nKey
    let path: WritableKeyPath<ImageAdjustments, Double>
    let range: ClosedRange<Double>
    let neutral: Double
    var id: L10nKey { label }

    static let light: [Self] = [
        .init(label: .editorExposure, path: \.exposure, range: ImageAdjustments.exposureRange, neutral: 0),
        .init(label: .editorBrightness, path: \.brightness, range: ImageAdjustments.brightnessRange, neutral: 0),
        .init(label: .editorContrast, path: \.contrast, range: ImageAdjustments.contrastRange, neutral: 1),
        .init(label: .editorHighlights, path: \.highlights, range: ImageAdjustments.unitRange, neutral: 0),
        .init(label: .editorShadows, path: \.shadows, range: ImageAdjustments.unitRange, neutral: 0)
    ]
    static let color: [Self] = [
        .init(label: .editorTemperature, path: \.temperature, range: ImageAdjustments.signedUnitRange, neutral: 0),
        .init(label: .editorTint, path: \.tint, range: ImageAdjustments.signedUnitRange, neutral: 0),
        .init(label: .editorSaturation, path: \.saturation, range: ImageAdjustments.saturationRange, neutral: 1),
        .init(label: .editorVibrance, path: \.vibrance, range: ImageAdjustments.signedUnitRange, neutral: 0)
    ]
    static let detail: [Self] = [
        .init(label: .editorSharpness, path: \.sharpness, range: ImageAdjustments.unitRange, neutral: 0),
        .init(label: .editorNoiseReduction, path: \.noiseReduction, range: ImageAdjustments.unitRange, neutral: 0),
        .init(label: .editorVignette, path: \.vignette, range: ImageAdjustments.unitRange, neutral: 0)
    ]
}
