import SwiftUI

@main
struct NotchyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(NotchyKeys.scrollSpeed) private var scrollSpeed: Double = 40

    var body: some Scene {
        // The settings window is our own (AppDelegate.showSettingsWindow); this empty scene only gives SwiftUI a scene
        // to hang the menu commands on.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "menu_settings")) {
                    AppDelegate.shared?.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "new_script")) {
                    AppDelegate.shared?.showScriptsWindow(newScript: true)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Button(String(localized: "menu_open_teleprompter")) {
                    AppDelegate.shared?.openTeleprompter()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                Button(String(localized: "menu_scripts")) {
                    AppDelegate.shared?.showScriptsWindow()
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
                    NotchyState.shared.resetReading()
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
