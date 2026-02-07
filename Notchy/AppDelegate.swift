import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindow: NotchWindow?
    /// Usamos NSWindowController para evitar referência direta à NSWindow (evita EXC_BAD_ACCESS ao reabrir configs).
    private var settingsWindowController: NSWindowController?
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var closeTeleprompterItem: NSMenuItem?
    private var pinToNotchItem: NSMenuItem?
    private var showOnSubmenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        // Não abre a janela do teleprompter ao iniciar — só pelo menu
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Notchy")
        } else {
            button.title = "N"
        }
        button.toolTip = "Notchy – Teleprompter"

        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: "Abrir Teleprompter", action: #selector(openTeleprompter), keyEquivalent: "t"))
        menu?.items.last?.keyEquivalentModifierMask = [.command, .shift]
        closeTeleprompterItem = NSMenuItem(title: "Fechar Teleprompter", action: #selector(closeTeleprompter), keyEquivalent: "")
        menu?.addItem(closeTeleprompterItem!)
        menu?.addItem(NSMenuItem.separator())
        let showOnItem = NSMenuItem(title: "Mostrar em", action: nil, keyEquivalent: "")
        showOnSubmenu = NSMenu()
        showOnItem.submenu = showOnSubmenu
        menu?.addItem(showOnItem)
        menu?.addItem(NSMenuItem(title: "Configurações…", action: #selector(openSettings), keyEquivalent: ","))
        pinToNotchItem = NSMenuItem(title: "Fixar no notch", action: #selector(pinToNotch), keyEquivalent: "d")
        pinToNotchItem?.keyEquivalentModifierMask = [.command, .shift]
        menu?.addItem(pinToNotchItem!)
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: "Sair", action: #selector(quit), keyEquivalent: "q"))

        for item in menu?.items ?? [] {
            item.target = self
        }
        menu?.delegate = self
        statusItem?.menu = menu
        updateMenuVisibility()
    }

    func updateMenuVisibility() {
        let hasWindow = notchWindow != nil
        let isVisible = notchWindow?.isVisible ?? false
        closeTeleprompterItem?.isEnabled = hasWindow && isVisible
        pinToNotchItem?.isEnabled = hasWindow
    }

    private func ensureTeleprompterWindow() {
        if notchWindow != nil { return }
        let state = NotchyState.shared
        let contentView = ContentView()
            .environmentObject(state.windowController)
            .environmentObject(state.audioMonitor)
            .environmentObject(state.scrollController)
        let window = NotchWindow()
        window.contentView = NSHostingView(rootView: contentView)
        state.windowController.setWindow(window)
        notchWindow = window
    }

    @objc private func openTeleprompter() {
        ensureTeleprompterWindow()
        NotchyState.shared.windowController.showTeleprompter()
        notchWindow?.makeKeyAndOrderFront(nil)
        updateMenuVisibility()
    }

    @objc private func closeTeleprompter() {
        notchWindow?.orderOut(nil)
        updateMenuVisibility()
    }

    @objc private func openSettings() {
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
            win.title = "Configurações"
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
}

extension AppDelegate: NSWindowDelegate {
    func windowDidClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow,
              let wc = settingsWindowController,
              closedWindow === wc.window else { return }
        closedWindow.delegate = nil
        settingsWindowController = nil
    }

    // Stub to satisfy optional NSWindowDelegate requirement and avoid "nearly matches windowDidExpose" warning
    func windowDidExpose(_ notification: Notification) {}
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuVisibility()
        rebuildShowOnSubmenu()
    }

    private func rebuildShowOnSubmenu() {
        guard let submenu = showOnSubmenu else { return }
        submenu.removeAllItems()
        let current = UserDefaults.standard.integer(forKey: preferredDisplayIDKey)
        for screen in screensForSelection() {
            let item = NSMenuItem(title: screen.name, action: #selector(selectScreenForNotchy(_:)), keyEquivalent: "")
            item.target = self
            item.tag = screen.id
            item.state = (screen.id == current) ? .on : .off
            submenu.addItem(item)
        }
    }
}
