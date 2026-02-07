import AppKit
import SwiftUI

// Set preferred app language before any UI or SwiftUI code runs, so the Settings window
// (and all String(localized:)) uses the correct language on the first launch after restart.
if let pref = UserDefaults.standard.string(forKey: NotchyKeys.preferredLanguage), !pref.isEmpty {
    UserDefaults.standard.set([pref, "en"], forKey: "AppleLanguages")
} else {
    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
}

NotchyApp.main()
