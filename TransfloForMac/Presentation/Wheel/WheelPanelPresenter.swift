import AppKit
import SwiftUI
import TransfloDomain

/// `WheelPresenting` backed by a `WheelPanel` hosting `WheelView` (Adapter pattern).
final class WheelPanelPresenter: WheelPresenting {
    var onHover: ((WheelPoint?) -> Bool)? {
        didSet { dropView.onHover = onHover }
    }

    var onDrop: ((WheelPoint) -> Bool)? {
        didSet { dropView.onDrop = onDrop }
    }

    var onPromisedDrop: ((WheelPoint, @escaping PromisedFileDelivery) -> Bool)? {
        didSet { dropView.onPromisedDrop = onPromisedDrop }
    }

    var onKey: ((WheelKeyCommand) -> Void)? {
        didSet { dropView.onKey = onKey }
    }

    var onClick: ((WheelPoint) -> Bool)? {
        didSet { dropView.onClick = onClick }
    }

    var onPointer: ((WheelPoint) -> Void)? {
        didSet { dropView.onPointer = onPointer }
    }

    private let panel: FloatingPanel
    private let dropView: WheelDropView
    /// The app that had focus before keyboard mode, to hand focus back on hide.
    private var previousApp: NSRunningApplication?

    init(viewModel: WheelViewModel, localizer: Localizer) {
        // Sized for the largest ring; smaller rings sit centered, so the drop point stays the center.
        let side = (AppDimensions.Wheel.fullOuterRadius * InterfaceCustomization.WheelSize.large.scale
                    + AppDimensions.Wheel.margin) * 2
        let size = CGSize(width: side, height: side)
        panel = FloatingPanel(size: size, identifier: WindowIdentifier.wheel)
        dropView = WheelDropView(frame: CGRect(origin: .zero, size: size))
        let host = NSHostingView(rootView: AppLocalizedRoot(localizer: localizer) {
            WheelView(viewModel: viewModel)
        })
        host.frame = dropView.bounds
        host.autoresizingMask = [.width, .height]
        dropView.addSubview(host)
        panel.contentView = dropView
    }

    func show(at point: WheelPoint) {
        let size = panel.frame.size
        let anchor = CGPoint(x: point.x, y: point.y)
        panel.place(origin: CGPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height / 2), anchor: anchor)
    }

    func showInteractive(at point: WheelPoint) {
        let frontmost = NSWorkspace.shared.frontmostApplication
        previousApp = frontmost == .current ? nil : frontmost
        panel.allowsKey = true
        dropView.tracksPointer = true
        show(at: point)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(dropView)
    }

    func hide() {
        panel.orderOut(nil)
        guard panel.allowsKey else { return }
        panel.allowsKey = false
        dropView.tracksPointer = false
        previousApp?.activate()
        previousApp = nil
    }
}
