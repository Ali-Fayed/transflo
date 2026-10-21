/// The immutable-by-convention settings shared by the preview and export Strategies.
public struct BackgroundStyle: Sendable, Hashable {
    public enum Fill: Sendable, Hashable {
        case solid(String)
        case gradient(BackgroundPreset)
    }

    public static let paddingRange = 0.0...0.3
    public static let cornerRange = 0.0...0.2
    public static let shadowRange = 0.0...100.0
    public static let plain = BackgroundStyle()
    public static let beautified = BackgroundStyle(fill: .gradient(.lagoon), padding: 0.12,
                                                   corners: 0.04, shadow: 35)

    public var fill: Fill
    public var padding: Double
    public var corners: Double
    public var shadow: Double
    public var ratio: BackgroundCanvasRatio

    public init(
        fill: Fill = .solid("#FFFFFF"),
        padding: Double = 0,
        corners: Double = 0,
        shadow: Double = 0,
        ratio: BackgroundCanvasRatio = .automatic
    ) {
        if case .solid(let color) = fill {
            let hex = color.hasPrefix("#") ? String(color.dropFirst()) : color
            self.fill = .solid(hex.count == 6 && UInt32(hex, radix: 16) != nil ? "#" + hex.uppercased() : "#FFFFFF")
        } else {
            self.fill = fill
        }
        self.padding = Self.clamp(padding, to: Self.paddingRange)
        self.corners = Self.clamp(corners, to: Self.cornerRange)
        self.shadow = Self.clamp(shadow, to: Self.shadowRange)
        self.ratio = ratio
    }

    public var validated: Self { Self(fill: fill, padding: padding, corners: corners, shadow: shadow, ratio: ratio) }

    public func canvasDimensions(imageWidth: Int, imageHeight: Int) -> (width: Double, height: Double) {
        guard imageWidth > 0, imageHeight > 0 else { return (0, 0) }
        let inset = Double(min(imageWidth, imageHeight)) * validated.padding * 2
        var width = Double(imageWidth) + inset
        var height = Double(imageHeight) + inset
        if let ratio = ratio.ratio {
            if width / height < ratio { width = height * ratio } else { height = width / ratio }
        }
        return (width.rounded(.up), height.rounded(.up))
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound
    }
}
