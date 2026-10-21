import SwiftUI

/// A wrapping Layout Strategy with explicit reading-direction placement.
struct AppFlowLayout: Layout {
    let spacing: CGFloat
    let isRightToLeft: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let frames = frames(width: proposal.width, subviews: subviews)
        return CGSize(width: proposal.width ?? frames.map(\.maxX).max() ?? 0,
                      height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, frame) in frames(width: bounds.width, subviews: subviews).enumerated() {
            let x = isRightToLeft ? bounds.maxX - frame.maxX : bounds.minX + frame.minX
            subviews[index].place(at: CGPoint(x: x, y: bounds.minY + frame.minY), anchor: .topLeading,
                                  proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(width: CGFloat?, subviews: Subviews) -> [CGRect] {
        let maximum = max(1, width ?? .greatestFiniteMagnitude)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var result: [CGRect] = []
        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let size = subview.sizeThatFits(ProposedViewSize(width: min(ideal.width, maximum), height: nil))
            if x > 0, x + size.width > maximum {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            result.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return result
    }
}
