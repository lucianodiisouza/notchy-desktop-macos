import AppKit
import SwiftUI

// Prefer App Group as source of truth so language set in Notchy Scripts applies to Notchy too.
if let suite = UserDefaults(suiteName: NotchyKeys.appGroupIdentifier),
   let prefFromGroup = suite.string(forKey: NotchyKeys.preferredLanguage), !prefFromGroup.isEmpty {
    UserDefaults.standard.set(prefFromGroup, forKey: NotchyKeys.preferredLanguage)
}

// Set preferred app language before any UI or SwiftUI code runs, so the Settings window
// (and all String(localized:)) uses the correct language on the first launch after restart.
if let pref = UserDefaults.standard.string(forKey: NotchyKeys.preferredLanguage), !pref.isEmpty {
    UserDefaults.standard.set([pref, "en"], forKey: "AppleLanguages")
} else {
    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
}

// Sync to App Group so Notchy Scripts uses the same language as Settings and teleprompter.
let prefForGroup = UserDefaults.standard.string(forKey: NotchyKeys.preferredLanguage) ?? ""
UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)?.set(prefForGroup, forKey: NotchyKeys.preferredLanguage)

NotchyApp.main()
