import Foundation

/// Localization helper. Use in AppDelegate, ScriptStore, or when building strings programmatically.
/// SwiftUI: prefer `Text("key")` so the key is looked up from Localizable.strings automatically.
enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: args)
    }
}
