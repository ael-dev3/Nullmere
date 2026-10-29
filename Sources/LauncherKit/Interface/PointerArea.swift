import AppKit
import SwiftUI

extension View {
    /// Tells `action` when the pointer comes over this view and when it
    /// leaves, as `onHover` would, through AppKit's own tracking area.
    ///
    /// SwiftUI's hover keeps the views it last found under the pointer, and
    /// the hosting view around them, until the pointer moves again: the
    /// launcher, taken out of its window as Play crosses to the realm, would
    /// stay alive with its Metal lake. A tracking area holds nothing.
    func onPointer(_ action: @escaping (Bool) -> Void) -> some View {
        background(PointerArea(cursor: nil, onChange: action))
    }

    /// The pointing hand over this view, as over a link, set by AppKit's
    /// cursor rects rather than SwiftUI's pointer style, for the same reason.
    func linkPointer() -> some View {
        background(PointerArea(cursor: .pointingHand, onChange: nil))
    }
}

/// An area of the window that hears the pointer come and go, and shows a
/// cursor while it is there; clicks pass through it to what lies beneath.
struct PointerArea: NSViewRepresentable {
    var cursor: NSCursor?
    var onChange: ((Bool) -> Void)?

    func makeNSView(context: Context) -> PointerAreaView {
        PointerAreaView(cursor: cursor, onChange: onChange)
    }

    func updateNSView(_ view: PointerAreaView, context: Context) {
        view.cursor = cursor
        view.onChange = onChange
    }

    static func dismantleNSView(_ view: PointerAreaView, coordinator: ()) {
        view.removeFromSuperview()
    }
}

final class PointerAreaView: NSView {
    var cursor: NSCursor? {
        didSet {
            if cursor != oldValue { window?.invalidateCursorRects(for: self) }
        }
    }
    var onChange: ((Bool) -> Void)?
    /// The pointer is over the area.
    private(set) var isInside = false

    init(cursor: NSCursor?, onChange: ((Bool) -> Void)?) {
        self.cursor = cursor
        self.onChange = onChange
        super.init(frame: .zero)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Clicks go to what the area lies under.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func resetCursorRects() {
        if let cursor { addCursorRect(bounds, cursor: cursor) }
    }

    override func mouseEntered(with event: NSEvent) {
        pointer(isInside: true)
    }

    override func mouseExited(with event: NSEvent) {
        pointer(isInside: false)
    }

    /// The pointer came over the area or left it; told once for each.
    func pointer(isInside inside: Bool) {
        guard inside != isInside else { return }
        isInside = inside
        onChange?(inside)
    }
}
