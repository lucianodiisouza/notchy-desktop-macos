import AppKit

/// Height of the menu bar strip when the Mac has no notch (fallback).
let fallbackNotchHeight: CGFloat = 28

/// Effective height of the top strip (notch + menu bar area) for positioning the prompter.
/// On macOS Sequoia (15+) the relationship between visibleFrame and the notch can differ;
/// this prefers safeAreaInsets when available, then visibleFrame, then a fixed fallback.
func effectiveTopStripHeight(for screen: NSScreen) -> CGFloat {
    let full = screen.frame
    let visible = screen.visibleFrame
    let fromVisible = full.maxY - visible.maxY

    if #available(macOS 12.0, *) {
        let safeTop = screen.safeAreaInsets.top
        // When there's a notch, safeAreaInsets.top is the inset from the physical top (notch height).
        // Use it as the strip height when it's the largest/most reliable value.
        if safeTop > 0 {
            // Prefer the larger of the two so we don't end up below the status bar (e.g. on Sequoia).
            return max(safeTop, fromVisible > 0 ? fromVisible : fallbackNotchHeight)
        }
    }

    return fromVisible > 0 ? fromVisible : fallbackNotchHeight
}

extension NSScreen {
    /// CGDirectDisplayID for this screen (from deviceDescription).
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// The screen with the menu bar. `NSScreen.main` is the one with the key window instead, which is often the prompter.
var menuBarScreen: NSScreen? { NSScreen.screens.first }

/// List of (displayID, displayName) for all screens, for picker/submenu. Option 0 = the menu bar screen; then one per screen.
func screensForSelection() -> [(id: Int, name: String)] {
    var list: [(id: Int, name: String)] = [(0, NSLocalizedString("display_menu_bar_screen", comment: ""))]
    let primary = menuBarScreen
    for screen in NSScreen.screens {
        guard let did = screen.displayID else { continue }
        let id = Int(did)
        let name = screen.localizedName
        list.append((id: id, name: screen === primary ? String(format: NSLocalizedString("display_primary_format", comment: ""), name) : name))
    }
    return list
}

/// Resolve NSScreen from stored preferred display ID (0 = the menu bar screen).
func screenForPreferredDisplayID(_ preferredID: Int) -> NSScreen? {
    if preferredID == 0 { return menuBarScreen }
    return NSScreen.screens.first { Int($0.displayID ?? 0) == preferredID } ?? menuBarScreen
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
