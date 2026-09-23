import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The running delegate. `NSApp.delegate` is SwiftUI's adaptor, not this class, so views that open a window reach
    /// it through here.
    private(set) static weak var shared: AppDelegate?

    private var notchWindow: NotchWindow?
    private var settingsController: SettingsWindowController?
    private var scriptsController: ScriptsWindowController?
    private var statusItem: NSStatusItem?
    private var pinToNotchItem: NSMenuItem?
    private var toggleItem: NSMenuItem?
    private var updateItem: NSMenuItem?
    private var showOnSubmenu: NSMenu?

    /// Settings and Scripts windows currently open. While any is up the app is `.regular`, so the window has a Dock
    /// icon, a menu bar and a place in ⌘Tab; with none it goes back to living in the notch.
    private var userWindowCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        openTeleprompter()
        UpdateChecker.shared.checkForUpdates()
        #if DEBUG
        // `-NotchyDebugOpen settings.voice` or `-NotchyDebugOpen scripts` opens a window on launch, for screenshots.
        if let target = UserDefaults.standard.string(forKey: "NotchyDebugOpen") {
            if target == "scripts" {
                showScriptsWindow()
            } else if target.hasPrefix("settings") {
                showSettingsWindow(SettingsPageID(rawValue: String(target.dropFirst("settings.".count))))
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotchyState.shared.audioMonitor.stop()
    }

    /// Opening the app again from Finder or Spotlight while it runs brings the prompter back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openTeleprompter()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.scheme == "notchy" }) {
            openTeleprompter()
        }
    }

    // MARK: - Menu bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            image.accessibilityDescription = String(localized: "menu_tooltip")
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "text.aligncenter", accessibilityDescription: String(localized: "menu_tooltip"))
        }
        button.toolTip = String(localized: "menu_tooltip")

        let menu = NSMenu()
        let toggle = NSMenuItem(title: String(localized: "menu_toggle_prompter"), action: #selector(toggleTeleprompter), keyEquivalent: "t")
        toggle.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(toggle)
        toggleItem = toggle
        let pin = NSMenuItem(title: String(localized: "menu_pin_to_notch"), action: #selector(pinToNotch), keyEquivalent: "d")
        pin.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(pin)
        pinToNotchItem = pin
        let showOn = NSMenuItem(title: String(localized: "menu_show_on"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        showOn.submenu = submenu
        showOnSubmenu = submenu
        menu.addItem(showOn)
        menu.addItem(.separator())
        let scripts = NSMenuItem(title: String(localized: "menu_scripts"), action: #selector(openScripts), keyEquivalent: "r")
        scripts.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(scripts)
        menu.addItem(NSMenuItem(title: String(localized: "menu_settings"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        let update = NSMenuItem(title: "", action: #selector(openUpdate), keyEquivalent: "")
        update.isHidden = true
        menu.addItem(update)
        updateItem = update
        menu.addItem(NSMenuItem(title: String(localized: "menu_quit"), action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        menu.delegate = self
        statusItem?.menu = menu
    }

    // MARK: - Teleprompter

    private func ensureTeleprompterWindow() {
        if notchWindow != nil { return }
        let state = NotchyState.shared
        let contentView = ContentView()
            .environmentObject(state.windowController)
            .environmentObject(state.audioMonitor)
            .environmentObject(state.scrollController)
            .environmentObject(state.speechFollower)
        let window = NotchWindow()
        window.contentView = NSHostingView(rootView: contentView)
        state.windowController.setWindow(window)
        notchWindow = window
    }

    func openTeleprompter() {
        ensureTeleprompterWindow()
        NotchyState.shared.windowController.showTeleprompter()
        notchWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleTeleprompter() {
        if notchWindow?.isVisible ?? false {
            notchWindow?.orderOut(nil)
        } else {
            openTeleprompter()
        }
    }

    @objc private func pinToNotch() {
        guard notchWindow != nil else { return }
        NotchyState.shared.windowController.pinWindowToNotch()
        notchWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func selectScreenForNotchy(_ sender: NSMenuItem) {
        NotchyState.shared.windowController.setPreferredDisplayID(sender.tag)
        if notchWindow != nil {
            NotchyState.shared.windowController.pinWindowToNotch()
            notchWindow?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Windows

    @objc func openSettings() {
        showSettingsWindow()
    }

    @objc private func openScripts() {
        showScriptsWindow()
    }

    func showSettingsWindow(_ page: SettingsPageID? = nil) {
        if settingsController == nil {
            let controller = SettingsWindowController()
            controller.onClose = { [weak self] in
                self?.settingsController = nil
                self?.userWindowDidClose()
            }
            settingsController = controller
            userWindowDidOpen()
        }
        settingsController?.show(page)
    }

    /// Opens the Scripts window. `newScript` starts an untitled script in it, for ⌘N.
    func showScriptsWindow(newScript: Bool = false, select id: UUID? = nil) {
        if scriptsController == nil {
            let controller = ScriptsWindowController()
            controller.onClose = { [weak self] in
                self?.scriptsController = nil
                self?.userWindowDidClose()
            }
            scriptsController = controller
            userWindowDidOpen()
        }
        scriptsController?.show(newScript: newScript, select: id)
    }

    private func userWindowDidOpen() {
        userWindowCount += 1
        if userWindowCount == 1 {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func userWindowDidClose() {
        userWindowCount = max(0, userWindowCount - 1)
        if userWindowCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func openUpdate() {
        UpdateChecker.shared.openReleasePage()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        pinToNotchItem?.isEnabled = notchWindow != nil
        toggleItem?.title = (notchWindow?.isVisible ?? false)
            ? String(localized: "menu_close_teleprompter")
            : String(localized: "menu_open_teleprompter")
        if let update = UpdateChecker.shared.availableUpdate {
            updateItem?.title = String(format: String(localized: "menu_update_available"), update.version)
            updateItem?.isHidden = false
        } else {
            updateItem?.isHidden = true
        }
        rebuildShowOnSubmenu()
    }

    private func rebuildShowOnSubmenu() {
        guard let submenu = showOnSubmenu else { return }
        submenu.removeAllItems()
        let current = UserDefaults.standard.integer(forKey: NotchyKeys.preferredDisplayID)
        for screen in screensForSelection() {
            let item = NSMenuItem(title: screen.name, action: #selector(selectScreenForNotchy(_:)), keyEquivalent: "")
            item.target = self
            item.tag = screen.id
            item.state = (screen.id == current) ? .on : .off
            submenu.addItem(item)
        }
    }
}
