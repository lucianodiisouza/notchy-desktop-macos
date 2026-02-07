import AppKit

/// Height of the menu bar strip when the Mac has no notch (fallback).
let fallbackNotchHeight: CGFloat = 28

extension NSScreen {
    /// CGDirectDisplayID for this screen (from deviceDescription).
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// List of (displayID, displayName) for all screens, for picker/submenu. Option 0 = main; then one per screen.
func screensForSelection() -> [(id: Int, name: String)] {
    var list: [(id: Int, name: String)] = [(0, "Principal (tela do menu)")]
    let screens = NSScreen.screens
    let main = NSScreen.main
    for screen in screens {
        guard let did = screen.displayID else { continue }
        let id = Int(did)
        let name: String
        if #available(macOS 10.15, *) {
            name = screen.localizedName
        } else {
            name = "Display \(id)"
        }
        let isMain = screen === main
        list.append((id: id, name: isMain ? "\(name) (principal)" : name))
    }
    return list
}

/// Resolve NSScreen from stored preferred display ID (0 = main).
func screenForPreferredDisplayID(_ preferredID: Int) -> NSScreen? {
    if preferredID == 0 { return NSScreen.main }
    let screens = NSScreen.screens
    return screens.first { Int($0.displayID ?? 0) == preferredID } ?? NSScreen.main
}

/// Screen that contains the window (by center point). Used to detect current monitor when docking or after drag.
func screenContaining(window: NSWindow) -> NSScreen? {
    let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
    return NSScreen.screens.first { $0.frame.contains(center) }
}

/// Union of all screens' visible frames (same coordinate system). Use when window is in free position so it can be dragged to any monitor.
func combinedVisibleFrameOfAllScreens() -> CGRect {
    let screens = NSScreen.screens
    guard let first = screens.first else { return .zero }
    var combined = first.visibleFrame
    for screen in screens.dropFirst() {
        combined = combined.union(screen.visibleFrame)
    }
    return combined
}
