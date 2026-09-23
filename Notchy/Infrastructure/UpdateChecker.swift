import Foundation
import AppKit
import Combine

/// Polls the project's GitHub Releases and, when the latest published release
/// is newer than the running build, publishes it so the menu bar and Settings can offer a
/// "New version available" item that opens the release page.
///
/// The Mac App Store build is compiled with the `APPSTORE` condition
/// (see `scripts/appstore.sh`): the store delivers its updates, so there the
/// checker never touches the network.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    /// The newer release, once one is found. `nil` means "up to date / not
    /// checked yet".
    @Published private(set) var availableUpdate: Release?

    /// A release worth surfacing to the user.
    struct Release: Equatable {
        /// Human-readable version, with any leading "v" stripped (e.g. "0.0.3").
        let version: String
        /// The GitHub release page to open when the user clicks the item.
        let url: URL
    }

    /// `owner/repo` for the releases endpoint.
    private let repo = "lucianodiisouza/notchy-desktop-macos"

    /// Don't hammer the API — re-check at most this often.
    private let minInterval: TimeInterval = 60 * 60 * 6
    private var lastCheck: Date?

    /// `false` in the App Store build, where the store handles updates.
    static var isEnabled: Bool {
        #if APPSTORE
        return false
        #else
        return true
        #endif
    }

    /// Set while a manual check (from Settings) is in flight.
    @Published private(set) var isChecking = false
    /// When the last check finished, successful or not.
    @Published private(set) var lastChecked: Date?

    /// The running app version (`CFBundleShortVersionString`), e.g. "0.0.1".
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Fetch the latest release and publish it if it's newer than the running
    /// build. Safe to call repeatedly; throttled by `minInterval` unless
    /// `force` is set. Network/parse failures are swallowed — a failed check
    /// simply leaves the menu in its "up to date" state.
    func checkForUpdates(force: Bool = false) {
        guard Self.isEnabled else { return }
        if !force, let last = lastCheck, Date().timeIntervalSince(last) < minInterval {
            return
        }
        lastCheck = Date()

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Notchy", forHTTPHeaderField: "User-Agent")

        isChecking = true
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.isChecking = false
                self.lastChecked = Date()
            }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                self.apply(release)
            } catch {
                // Offline or rate-limited — leave state unchanged.
            }
        }
    }

    /// Open the pending release's GitHub page in the default browser.
    func openReleasePage() {
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.url)
    }

    // MARK: - Private

    private func apply(_ release: GitHubRelease) {
        // Skip drafts and prereleases — only stable, published releases count.
        guard !release.draft, !release.prerelease else { return }
        let latest = Self.normalized(release.tagName)
        guard let pageURL = URL(string: release.htmlURL),
              Self.isNewer(latest, than: Self.normalized(currentVersion)) else {
            availableUpdate = nil
            return
        }
        availableUpdate = Release(version: latest, url: pageURL)
    }

    /// Strip a leading "v" and trim whitespace: "v0.0.3" -> "0.0.3".
    private static func normalized(_ tag: String) -> String {
        var s = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        return s
    }

    /// Numeric, component-wise semantic-version comparison. Non-numeric or
    /// missing components are treated as 0, so "1.2" < "1.2.1".
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let a = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

/// The subset of the GitHub release payload we care about.
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft
        case prerelease
    }
}
