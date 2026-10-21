/// Stroke thickness presets, as a fraction of the image's shorter side (text is four times this).
enum MarkupWeight: Double, Hashable, CaseIterable {
    case thin = 0.006
    case medium = 0.012
    case thick = 0.024
}
