import SwiftUI

struct NotchyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(NotchyKeys.scrollSpeed) private var scrollSpeed: Double = 40

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button(String(localized: "menu_open_teleprompter")) {
                    NotchyState.shared.windowController.showTeleprompter()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                Button(String(localized: "menu_open_scripts")) {
                    AppDelegate.launchScriptsApp()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button(String(localized: "menu_pin_to_notch")) {
                    NotchyState.shared.windowController.pinWindowToNotch()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .help(String(localized: "menu_pin_to_notch_help"))
            }
            CommandGroup(after: .windowSize) {
                Button(String(localized: "menu_reset_scroll")) {
                    NotchyState.shared.scrollController.resetScroll()
                }
                .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button(String(localized: "menu_faster")) {
                    scrollSpeed = min(120, scrollSpeed + 10)
                }
                .keyboardShortcut(.upArrow, modifiers: .shift)
                Button(String(localized: "menu_slower")) {
                    scrollSpeed = max(10, scrollSpeed - 10)
                }
                .keyboardShortcut(.downArrow, modifiers: .shift)
            }
        }
    }
}
