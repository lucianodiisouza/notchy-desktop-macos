import Foundation
import ObjectiveC

/// Bundle subclass that localizes using the user's preferred app language (Settings) when set,
/// so the app can use a different language than the system without restart.
/// Installed in AppDelegate applicationWillFinishLaunching.
final class PreferredLanguageBundle: Bundle, @unchecked Sendable {

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let preferredId = UserDefaults.standard.string(forKey: NotchyKeys.preferredLanguage),
              !preferredId.isEmpty,
              let path = Bundle.main.path(forResource: preferredId, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        let string = bundle.localizedString(forKey: key, value: value, table: tableName)
        if string != key && !string.isEmpty { return string }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }

    /// Call once at app launch, before any UI loads.
    static func installIfNeeded() {
        guard !(Bundle.main is PreferredLanguageBundle) else { return }
        object_setClass(Bundle.main, PreferredLanguageBundle.self)
    }
}
