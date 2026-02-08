import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    /// Usamos NSWindowController para evitar referência direta à NSWindow (evita EXC_BAD_ACCESS ao reabrir configs).
    private var settingsWindowController: NSWindowController?
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var pinToNotchItem: NSMenuItem?
    private var showOnSubmenu: NSMenu?
    private var accountMenuItem: NSMenuItem?
    private var selectedScriptObserver: NSObjectProtocol?
    private var premiumCancellable: AnyCancellable?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // AppleLanguages is set in main.swift before any UI runs. Install bundle override for NSLocalizedString.
        PreferredLanguageBundle.installIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush UserDefaults so preferred language and other settings persist before quit.
        UserDefaults.standard.synchronize()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Sync language with App Group here (not in main.swift) so the system permission
        // "access data from other apps" is not triggered before the app is ready.
        syncPreferredLanguageWithAppGroup()
        PremiumService.shared.start()
        setupStatusBar()
        observeSelectedScriptChanges()
        openTeleprompter()
    }

    /// Syncs preferred language with the App Group (so Notchy and Notchy Scripts stay in sync).
    /// Call only after the app is running to avoid triggering the permission dialog at startup.
    private func syncPreferredLanguageWithAppGroup() {
        let suite = UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)
        if let prefFromGroup = suite?.string(forKey: NotchyKeys.preferredLanguage), !prefFromGroup.isEmpty {
            UserDefaults.standard.set(prefFromGroup, forKey: NotchyKeys.preferredLanguage)
            UserDefaults.standard.set([prefFromGroup, "en"], forKey: "AppleLanguages")
            PreferredLanguageBundle.installIfNeeded()
        }
        let pref = UserDefaults.standard.string(forKey: NotchyKeys.preferredLanguage) ?? ""
        suite?.set(pref, forKey: NotchyKeys.preferredLanguage)
    }

    private func observeSelectedScriptChanges() {
        selectedScriptObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(NotchyKeys.selectedScriptDidChangeNotification),
            object: nil,
            queue: .main
        ) { _ in
            ScriptStore.shared.syncFromSharedStorage()
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let customImage = NSImage(named: "16") {
            customImage.isTemplate = true
            customImage.accessibilityDescription = NSLocalizedString("menu_tooltip", comment: "")
            button.image = customImage
        } else if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: NSLocalizedString("menu_tooltip", comment: ""))
        } else {
            button.title = NSLocalizedString("menu_bar_title", comment: "")
        }
        button.toolTip = NSLocalizedString("menu_tooltip", comment: "")

        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: NSLocalizedString("menu_toggle_prompter", comment: ""), action: #selector(toggleTeleprompter), keyEquivalent: "t"))
        menu?.items.last?.keyEquivalentModifierMask = [.command, .shift]
        pinToNotchItem = NSMenuItem(title: NSLocalizedString("menu_pin_to_notch", comment: ""), action: #selector(pinToNotch), keyEquivalent: "d")
        pinToNotchItem?.keyEquivalentModifierMask = [.command, .shift]
        menu?.addItem(pinToNotchItem!)
        let showOnItem = NSMenuItem(title: NSLocalizedString("menu_show_on", comment: ""), action: nil, keyEquivalent: "")
        showOnSubmenu = NSMenu()
        showOnItem.submenu = showOnSubmenu
        menu?.addItem(showOnItem)
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: NSLocalizedString("menu_settings", comment: ""), action: #selector(openSettings), keyEquivalent: ","))
        menu?.items.last?.keyEquivalentModifierMask = .command
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: NSLocalizedString("menu_open_scripts", comment: ""), action: #selector(openScripts), keyEquivalent: "r"))
        menu?.items.last?.keyEquivalentModifierMask = [.command, .shift]
        menu?.addItem(NSMenuItem.separator())
        accountMenuItem = NSMenuItem(title: "", action: #selector(refreshPremiumStatus), keyEquivalent: "")
        accountMenuItem?.toolTip = NSLocalizedString("menu_account_refresh_hint", comment: "")
        menu?.addItem(accountMenuItem!)
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: NSLocalizedString("menu_quit", comment: ""), action: #selector(quit), keyEquivalent: "q"))

        for item in menu?.items ?? [] {
            item.target = self
        }
        menu?.delegate = self
        statusItem?.menu = menu
        updateMenuVisibility()
        updatePremiumIndicator()
        premiumCancellable = Publishers.CombineLatest(PremiumService.shared.$isPremium, PremiumService.shared.$isBanned)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePremiumIndicator()
            }
    }

    /// Updates the account menu item title (Premium / Free / Suspended).
    private func updatePremiumIndicator() {
        let service = PremiumService.shared
        if service.isBanned {
            accountMenuItem?.title = NSLocalizedString("menu_account_banned", comment: "")
        } else if service.isPremium {
            accountMenuItem?.title = NSLocalizedString("menu_account_premium", comment: "")
        } else {
            accountMenuItem?.title = NSLocalizedString("menu_account_free", comment: "")
        }
    }

    /// Called when user clicks the account menu item: fetches current premium status from backend.
    @objc private func refreshPremiumStatus() {
        PremiumService.shared.checkPremium()
    }

    func updateMenuVisibility() {
        let hasWindow = notchWindow != nil
        pinToNotchItem?.isEnabled = hasWindow
    }

    private func ensureTeleprompterWindow() {
        if notchWindow != nil { return }
        let state = NotchyState.shared
        let contentView = ContentView()
            .environmentObject(state.windowController)
            .environmentObject(state.audioMonitor)
            .environmentObject(state.scrollController)
            .environmentObject(PremiumService.shared)
        let window = NotchWindow()
        window.contentView = NSHostingView(rootView: contentView)
        state.windowController.setWindow(window)
        notchWindow = window
    }

    @objc private func toggleTeleprompter() {
        let isVisible = notchWindow?.isVisible ?? false
        if isVisible {
            notchWindow?.orderOut(nil)
        } else {
            ensureTeleprompterWindow()
            NotchyState.shared.windowController.showTeleprompter()
            notchWindow?.makeKeyAndOrderFront(nil)
        }
        updateMenuVisibility()
    }

    @objc private func openTeleprompter() {
        ensureTeleprompterWindow()
        NotchyState.shared.windowController.showTeleprompter()
        notchWindow?.makeKeyAndOrderFront(nil)
        updateMenuVisibility()
    }

    @objc private func openScripts() {
        Self.launchScriptsApp()
    }

    /// Launches the Notchy Scripts app (embedded, sibling in dev, or by bundle id). Call from menu or SwiftUI commands.
    static func launchScriptsApp() {
        let scriptsAppName = "Notchy Scripts.app"
        let fileManager = FileManager.default

        // 1) Embedded (release/archive): Notchy.app/Contents/Applications/Notchy Scripts.app
        let embeddedURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Applications")
            .appendingPathComponent(scriptsAppName)
        if fileManager.fileExists(atPath: embeddedURL.path) {
            NSWorkspace.shared.open(embeddedURL)
            return
        }

        // 2) Dev (Xcode): Notchy Scripts.app as sibling in Build/Products/Debug or Build/Products/Release
        let siblingURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent(scriptsAppName)
        if fileManager.fileExists(atPath: siblingURL.path) {
            NSWorkspace.shared.open(siblingURL)
            return
        }

        // 3) Installed app by bundle id (e.g. /Applications)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.notchy.scripts") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openSettings() {
        // Se a janela foi fechada, o controller foi nulado no delegate → criamos uma nova.
        if settingsWindowController == nil {
            let content = SettingsView()
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.minSize = NSSize(width: 480, height: 420)
            win.title = NSLocalizedString("window_title_settings", comment: "")
            win.contentView = NSHostingView(rootView: content)
            win.center()
            win.delegate = self
            settingsWindowController = NSWindowController(window: win)
        }
        guard let wc = settingsWindowController, let win = wc.window else { return }
        if notchWindow != nil {
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        } else {
            win.level = .normal
        }
        NSApp.activate(ignoringOtherApps: true)
        wc.showWindow(nil)
    }

    @objc private func pinToNotch() {
        guard notchWindow != nil else { return }
        NotchyState.shared.windowController.pinWindowToNotch()
        notchWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func selectScreenForNotchy(_ sender: NSMenuItem) {
        let displayID = sender.tag
        NotchyState.shared.windowController.setPreferredDisplayID(displayID)
        if notchWindow != nil {
            NotchyState.shared.windowController.pinWindowToNotch()
            notchWindow?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "notchy" && url.host == "openTeleprompter" {
            NSApp.activate(ignoringOtherApps: true)
            openTeleprompter()
            return
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              let wc = settingsWindowController,
              closedWindow === wc.window else { return }
        closedWindow.delegate = nil
        settingsWindowController = nil
    }

    // Stubs to satisfy optional NSWindowDelegate requirements and avoid "nearly matches" warnings
    func windowDidExpose(_ notification: Notification) {}
    func windowDidMove(_ notification: Notification) {}
    func windowWillClose(_ notification: Notification) {}
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuVisibility()
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
