import SwiftUI

@main
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
                Button("Show Teleprompter") {
                    NotchyState.shared.windowController.showTeleprompter()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("Abrir Roteiros") {
                    AppDelegate.launchScriptsApp()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Fixar no notch") {
                    NotchyState.shared.windowController.pinWindowToNotch()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .help("Recoloca a janela no notch (útil depois de arrastar)")
            }
            CommandGroup(after: .windowSize) {
                Button("Reset Scroll") {
                    NotchyState.shared.scrollController.resetScroll()
                }
                .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Faster") {
                    scrollSpeed = min(120, scrollSpeed + 10)
                }
                .keyboardShortcut(.upArrow, modifiers: .shift)
                Button("Slower") {
                    scrollSpeed = max(10, scrollSpeed - 10)
                }
                .keyboardShortcut(.downArrow, modifiers: .shift)
            }
        }
    }
}
