import SwiftUI

/// Menu-bar style blur so the notch bar looks like one piece with the system menu bar.
struct WindowBackgroundView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = false
        return effect
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
