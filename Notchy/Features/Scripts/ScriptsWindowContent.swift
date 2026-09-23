import AppKit
import SwiftUI

/// The Scripts window: folder tree and script list on the left, the editor on the right.
struct ScriptsWindowContent: View {
    @ObservedObject var navigation: ScriptsNavigation
    @ObservedObject private var store = ScriptStore.shared
    @State private var selectedScriptId: UUID?
    @State private var selectedFolderPath: String = ""
    @State private var expandedFolderPaths: Set<String> = []
    @AppStorage(NotchyKeys.scriptEditorTheme) private var themeRaw: Int = 0

    private var colorScheme: ColorScheme? {
        switch themeRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        // Same shape as the settings window: a sidebar running the full height with the traffic lights on it, and the
        // editor beside it.
        HStack(spacing: 0) {
            FolderTreeSidebarView(
                store: store,
                selectedScriptId: $selectedScriptId,
                selectedFolderPath: $selectedFolderPath,
                expandedFolderPaths: $expandedFolderPaths,
                onNewScript: createScript
            )
            .frame(width: 250)
            .ignoresSafeArea(.container, edges: .top)
            Group {
                if let id = selectedScriptId, let script = store.scripts.first(where: { $0.id == id }) {
                    ScriptEditorView(store: store, script: script)
                        // A fresh editor per script, so one script's pending text never lands in another.
                        .id(script.id)
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .top)
        }
        .onAppear {
            selectedScriptId = selectedScriptId ?? store.selectedScriptId
            if let id = selectedScriptId, let folder = store.scripts.first(where: { $0.id == id })?.folderPath, !folder.isEmpty {
                expandedFolderPaths.insert(folder)
            }
            handle(navigation.request)
        }
        .onChange(of: navigation.request) { _, request in handle(request) }
        .preferredColorScheme(colorScheme)
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            SettingsIcon(symbol: "doc.text.fill", color: Color(hex: "#64748B"), size: 56)
            Text(String(localized: "select_script_placeholder"))
                .font(.system(size: 18, weight: .bold))
            Text(String(localized: "select_script_help"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button(String(localized: "new_script"), action: createScript)
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
    }

    private func createScript() {
        if let id = store.createScript(
            title: String(localized: "script_untitled"),
            body: "",
            folderPath: selectedFolderPath
        ) {
            selectedScriptId = id
        }
    }

    private func handle(_ request: ScriptsNavigation.Request?) {
        guard let request else { return }
        navigation.request = nil
        switch request.kind {
        case .newScript: createScript()
        case .select(let id): selectedScriptId = id
        }
    }
}

/// What the app asked the Scripts window to do when it opened it (⌘N, or show a given script).
final class ScriptsNavigation: ObservableObject {
    struct Request: Equatable {
        enum Kind: Equatable {
            case newScript
            case select(UUID)
        }
        let kind: Kind
        let id = UUID()
    }

    @Published var request: Request?
}

/// Owns the single Scripts window.
@MainActor
final class ScriptsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let navigation = ScriptsNavigation()
    var onClose: (() -> Void)?

    func show(newScript: Bool = false, select id: UUID? = nil) {
        if newScript {
            navigation.request = .init(kind: .newScript)
        } else if let id {
            navigation.request = .init(kind: .select(id))
        }
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = String(localized: "scripts_nav_title")
            // No title bar: the sidebar runs to the top with the traffic lights on it, as in the settings window.
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 680, height: 440)
            window.contentViewController = NSHostingController(rootView: ScriptsWindowContent(navigation: navigation))
            window.setContentSize(NSSize(width: 900, height: 600))
            window.center()
            window.setFrameAutosaveName("NotchyScripts")
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onClose?()
    }
}
