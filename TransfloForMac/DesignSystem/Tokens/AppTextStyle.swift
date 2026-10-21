import CoreGraphics

/// Typographic roles. Rounded semibold headings give the utility a softer voice; body stays SF Pro.
enum AppTextStyle {
    case welcomeTitle
    case title
    case headline
    case body
    case caption
    /// A caption that names what follows it, such as a metadata field.
    case captionEmphasis
    /// Wedge labels: compact and semibold so they read over a moving pointer.
    /// The name in the wheel's hub pill.
    case wedgeCompact
    /// Wheel petal labels, sized by `WheelLabelMetrics` to fit the petal.
    case wheelLabel(size: CGFloat)
}
