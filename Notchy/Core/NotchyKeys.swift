import Foundation

/// Centralized UserDefaults keys for Notchy. Use these everywhere so we have a single place to see
/// what is persisted — useful for future sync/backend when scripts are synced.
enum NotchyKeys {
    /// App Group holding the scripts. Earlier versions shared it between Notchy and the separate Notchy Scripts app; it stays so their scripts carry over. The Team ID prefix avoids the "access data from other apps" prompt.
    static let appGroupIdentifier = "TJ7XUV6VQ9.com.notchy"
    /// Posted when preferred microphone changes so the audio monitor can restart with the new device.
    static let preferredMicrophoneDidChangeNotification = "com.notchy.preferredMicrophoneDidChange"
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
    /// Texto exibido na barra quando recolhida (ex.: nome do usuário). Vazio = "Notchy ▼"; máx. 20 caracteres.
    static let collapsedBarLabel = "collapsedBarLabel"

    // Voice & behavior
    static let voiceControlEnabled = "voiceControlEnabled"
    static let autoScrollPlaying = "autoScrollPlaying"
    static let pauseOnHover = "pauseOnHover"
    static let micSensitivity = "micSensitivity"
    /// Preferred microphone UID (Core Audio); empty = system default.
    static let preferredMicrophoneUID = "preferredMicrophoneUID"
    /// True after we have asked for microphone permission once; avoids showing the system dialog again.
    static let micPermissionRequestedOnce = "micPermissionRequestedOnce"
    /// How the voice drives the scroll: "level" (scroll while you make sound) or "follow" (track the words you say).
    static let voiceMode = "voiceMode"
    /// Locale identifier for "follow my words"; empty = pick from the script's language.
    static let speechLocale = "speechLocale"
    /// In "follow my words", fade the lines already read and mark the current one.
    static let highlightSpokenText = "highlightSpokenText"

    // Layout
    static let mirrorMode = "mirrorMode"
    static let textAlignment = "textAlignment"
    static let preferredDisplayID = "preferredDisplayID"
    /// Padding (pt) around script content in the teleprompter (0–40).
    static let contentPadding = "contentPadding"

    // Onboarding (first run)
    static let onboardingCompleted = "onboardingCompleted"

    // Script editor window
    static let scriptEditorFontSize = "scriptEditorFontSize"
    static let scriptEditorTheme = "scriptEditorTheme"  // 0 = system, 1 = light, 2 = dark
    static let scriptEditorLineSpacing = "scriptEditorLineSpacing"
    static let scriptEditorFontName = "scriptEditorFontName"  // empty = system default
}
