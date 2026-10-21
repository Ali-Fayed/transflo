import CoreGraphics
import Foundation

/// Explicit source order; indices always refer to the original drop, never a sorted filename list.
public struct AssemblySettings: Sendable, Hashable {
    public enum Paper: String, Sendable, Hashable, CaseIterable { case original, aFour, letter }
    public var order: [Int]
    public var paper: Paper
    public var landscape: Bool
    public var margin: Double
    public var fill: Bool

    public init(
        order: [Int],
        paper: Paper = .original,
        landscape: Bool = false,
        margin: Double = 24,
        fill: Bool = false
    ) {
        self.order = order
        self.paper = paper
        self.landscape = landscape
        self.margin = margin
        self.fill = fill
    }

    public func pageSize(original: CGSize) -> CGSize {
        let base: CGSize = switch paper {
        case .original: original
        case .aFour: CGSize(width: 595.276, height: 841.89)
        case .letter: CGSize(width: 612, height: 792)
        }
        return paper != .original && landscape ? CGSize(width: base.height, height: base.width) : base
    }

    /// Page-relative image placement, shared by the editor preview and PDF export.
    public func imageFrame(image: CGSize, page: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return .zero }
        let box = CGRect(origin: .zero, size: page)
        let content = box.insetBy(dx: min(max(0, margin), box.width / 3),
                                 dy: min(max(0, margin), box.height / 3))
        let scaleX = content.width / image.width
        let scaleY = content.height / image.height
        let scale = fill ? max(scaleX, scaleY) : min(scaleX, scaleY)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: content.midX - size.width / 2, y: content.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    public func ordered<T>(_ items: [T], minimum: Int = 2) -> [T]? {
        guard order.count >= minimum, Set(order).count == order.count,
              order.allSatisfy(items.indices.contains), margin.isFinite, (0...144).contains(margin) else { return nil }
        return order.map { items[$0] }
    }
}
