import AppKit
import SwiftUI

// Set preferred app language from standard UserDefaults only (no App Group here).
// App Group is touched only after the app is running (AppDelegate), so the system
// permission "access data from other apps" is not triggered before the app is ready.
if let pref = UserDefaults.standard.string(forKey: NotchyKeys.preferredLanguage), !pref.isEmpty {
    UserDefaults.standard.set([pref, "en"], forKey: "AppleLanguages")
} else {
    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
}

NotchyApp.main()
