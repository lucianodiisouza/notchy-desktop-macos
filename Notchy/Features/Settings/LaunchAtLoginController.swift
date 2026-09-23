import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` (macOS 13+) so the rest of the app can read
/// and toggle "launch at login". The service is the system-managed login item -
/// no separate helper binary, no privileged helper to install.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    /// Why the last change failed, shown under the switch. nil when it worked.
    @Published private(set) var error: String?

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Re-read the registration status. The user can remove the login item in
    /// System Settings at any time, so read it again whenever the page shows.
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login. Registration fails when the app runs
    /// from a translocated or unsigned location; the reason is kept in `error`.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        refresh()
    }
}
