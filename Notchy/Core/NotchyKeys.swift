import Foundation

/// Centralized UserDefaults keys for Notchy. Use these everywhere so we have a single place to see
/// what is persisted — useful for future sync/backend when scripts are synced.
enum NotchyKeys {
    /// App Group identifier for sharing scripts and selectedScriptId between Notchy and Notchy Scripts.
    static let appGroupIdentifier = "group.com.notchy"
    /// Distributed notification posted by Notchy Scripts when selected script changes; Notchy (main app) observes it to refresh.
    static let selectedScriptDidChangeNotification = "com.notchy.selectedScriptDidChange"
    /// URL to open the main app’s teleprompter (used by Notchy Scripts so “Usar no Teleprompter” opens the window).
    static let openTeleprompterURLString = "notchy://openTeleprompter"
    // Scroll & teleprompter
    static let scrollSpeed = "scrollSpeed"
    static let prompterText = "prompterText"

    // Scripts (App Group)
    static let selectedScriptId = "selectedScriptId"
    static let scriptsMigrationDone = "scriptsMigrationDone"

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
