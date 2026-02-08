import Foundation

/// Version info from the app bundle. Same MARKETING_VERSION and CURRENT_PROJECT_VERSION for Notchy and Notchy Scripts (set at project level in Xcode).
enum AppVersion {
    /// Short version string, e.g. "1.0" (CFBundleShortVersionString).
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Build number, e.g. "1" (CFBundleVersion).
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// Display string: "1.0 (1)".
    static var versionAndBuild: String {
        "\(marketingVersion) (\(buildNumber))"
    }

    /// App display name from bundle (e.g. "Notchy" or "Notchy Scripts").
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Notchy"
    }

    /// Full line for About / footer: "Notchy 1.0 (1)" or "Notchy Scripts 1.0 (1)".
    static var fullVersionLine: String {
        "\(appName) \(versionAndBuild)"
    }
}
