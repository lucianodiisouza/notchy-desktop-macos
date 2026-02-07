import AppKit

/// Borderless window that can still become key (for text input) and main.
/// Used so the notch bar has no chrome and looks like one piece with the menu bar.
final class NotchWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    /// Allow the window to sit in the menu bar strip. By default Cocoa constrains
    /// windows below the menu bar; we need to be *in* that strip (like NotchDrop).
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
