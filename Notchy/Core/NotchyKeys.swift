import Foundation

/// Centralized UserDefaults keys for Notchy. Use these everywhere so we have a single place to see
/// what is persisted — useful for future sync/backend when scripts are synced.
enum NotchyKeys {
    // Scroll & teleprompter
    static let scrollSpeed = "scrollSpeed"
    static let prompterText = "prompterText"

    // Text appearance
    static let fontSize = "fontSize"
    static let textColor = "textColor"
    static let textOpacity = "textOpacity"

    // Window
    static let windowOpacity = "windowOpacity"
    static let windowWidth = "windowWidth"
    static let windowHeight = "windowHeight"
    static let windowPinnedToNotch = "windowPinnedToNotch"
    static let windowFreeOriginX = "windowFreeOriginX"
    static let windowFreeOriginY = "windowFreeOriginY"
    static let showInScreenCapture = "showInScreenCapture"

    // Control bar
    static let buttonColorHex = "buttonColorHex"
    static let buttonOpacity = "buttonOpacity"

    // Voice & behavior
    static let voiceControlEnabled = "voiceControlEnabled"
    static let autoScrollPlaying = "autoScrollPlaying"
    static let micSensitivity = "micSensitivity"

    // Layout
    static let mirrorMode = "mirrorMode"
    static let textAlignment = "textAlignment"
    static let preferredDisplayID = "preferredDisplayID"
}
