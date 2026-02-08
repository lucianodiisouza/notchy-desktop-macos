import Foundation

/// Centralized UserDefaults keys for Notchy. Use these everywhere so we have a single place to see
/// what is persisted — useful for future sync/backend when scripts are synced.
enum NotchyKeys {
    /// App Group identifier for sharing scripts and selectedScriptId between Notchy and Notchy Scripts. macOS-style (Team ID prefix) = no "access data from other apps" prompt.
    static let appGroupIdentifier = "TJ7XUV6VQ9.com.notchy"
    /// Distributed notification posted by Notchy Scripts when selected script changes; Notchy (main app) observes it to refresh.
    static let selectedScriptDidChangeNotification = "com.notchy.selectedScriptDidChange"
    /// Posted when preferred microphone changes so the audio monitor can restart with the new device.
    static let preferredMicrophoneDidChangeNotification = "com.notchy.preferredMicrophoneDidChange"
    /// URL to open the main app’s teleprompter (used by Notchy Scripts so “Usar no Teleprompter” opens the window).
    static let openTeleprompterURLString = "notchy://openTeleprompter"
    /// Main Notchy app bundle IDs (menu bar / teleprompter). Used by Scripts to restart both apps when changing language.
    static let mainAppBundleIdentifiers = ["com.notchy.app", "dev.oprimo.notchy"]
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
    /// Cor de fundo da barra quando recolhida na faixa do notch (hex); útil para combinar com o wallpaper no screenshot.
    static let notchBackgroundColorHex = "notchBackgroundColorHex"

    // Voice & behavior
    static let voiceControlEnabled = "voiceControlEnabled"
    static let autoScrollPlaying = "autoScrollPlaying"
    static let pauseOnHover = "pauseOnHover"
    static let micSensitivity = "micSensitivity"
    /// Preferred microphone UID (Core Audio); empty = system default.
    static let preferredMicrophoneUID = "preferredMicrophoneUID"
    /// True after we have asked for microphone permission once; avoids showing the system dialog again.
    static let micPermissionRequestedOnce = "micPermissionRequestedOnce"

    // Layout
    static let mirrorMode = "mirrorMode"
    static let textAlignment = "textAlignment"
    static let preferredDisplayID = "preferredDisplayID"
    /// Padding (pt) around script content in the teleprompter (0–40).
    static let contentPadding = "contentPadding"

    // Language (in-app override; empty = system default)
    static let preferredLanguage = "preferredLanguage"

    // Onboarding (first run)
    static let onboardingCompleted = "onboardingCompleted"

    // Scripts editor (Notchy Scripts app; use App Group if shared with main app)
    static let scriptEditorFontSize = "scriptEditorFontSize"
    static let scriptEditorTheme = "scriptEditorTheme"  // 0 = system, 1 = light, 2 = dark
    static let scriptEditorLineSpacing = "scriptEditorLineSpacing"
    static let scriptEditorFontName = "scriptEditorFontName"  // empty = system default
    static let scriptEditorShowPreview = "scriptEditorShowPreview"  // show Markdown preview pane
}
