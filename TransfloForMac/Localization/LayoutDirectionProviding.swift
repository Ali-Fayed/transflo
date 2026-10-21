/// Tells non-view code whether the interface currently reads right-to-left.
protocol LayoutDirectionProviding: AnyObject {
    var isRightToLeft: Bool { get }
}
