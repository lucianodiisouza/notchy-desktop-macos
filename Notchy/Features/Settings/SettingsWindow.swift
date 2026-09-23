import AppKit
import SwiftUI

/// Pages of the settings window.
enum SettingsPageID: String, CaseIterable, Identifiable {
    case text, scrolling, voice, notch, editor, general, shortcuts, about

    var id: String { rawValue }

    /// Localizable.strings key of the page name.
    var title: String {
        switch self {
        case .text: return "settings_page_text"
        case .scrolling: return "settings_page_scrolling"
        case .voice: return "settings_page_voice"
        case .notch: return "settings_page_notch"
        case .editor: return "settings_page_editor"
        case .general: return "settings_page_general"
        case .shortcuts: return "settings_page_shortcuts"
        case .about: return "settings_page_about"
        }
    }

    var symbol: String {
        switch self {
        case .text: return "textformat"
        case .scrolling: return "arrow.up.arrow.down"
        case .voice: return "waveform"
        case .notch: return "rectangle.topthird.inset.filled"
        case .editor: return "doc.richtext"
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .text: return Color(hex: "#F97316")
        case .scrolling: return Color(hex: "#0EA5E9")
        case .voice: return Color(hex: "#EF4444")
        case .notch: return Color(hex: "#8B5CF6")
        case .editor: return Color(hex: "#22C55E")
        case .general: return Color(hex: "#6B7280")
        case .shortcuts: return Color(hex: "#6366F1")
        case .about: return Color(hex: "#475569")
        }
    }

    /// Keys of the row and group titles on this page the sidebar search can find. They must match the titles on the
    /// page so a result can scroll to its row.
    var searchableSettings: [String] {
        switch self {
        case .text: return ["label_font_size", "picker_text_color", "label_text_opacity", "alignment_menu", "mirror_menu", "label_content_padding"]
        case .scrolling: return ["label_scroll_speed", "toggle_pause_on_hover", "scroll_auto_short"]
        case .voice: return ["toggle_listen", "voice_mode_level", "voice_mode_follow", "label_sensitivity", "picker_microphone", "picker_speech_language", "toggle_highlight_spoken"]
        case .notch: return ["picker_monitor", "label_width", "label_expanded_height", "label_window_opacity", "picker_notch_background", "label_collapsed_bar", "picker_button_color", "label_button_opacity", "toggle_show_in_capture", "button_pin_back"]
        case .editor: return ["label_font_size_editor", "picker_editor_theme", "label_line_spacing", "field_font_name"]
        case .general: return ["setting_open_at_login", "section_language", "setting_your_scripts", "export_all_scripts", "setting_restore_defaults"]
        case .shortcuts: return ["shortcuts_group_anywhere", "shortcuts_group_prompter", "shortcuts_group_scripts"]
        case .about: return ["setting_updates", "setting_source_code", "setting_privacy"]
        }
    }

    static let sections: [[SettingsPageID]] = [
        [.text, .scrolling, .voice, .notch],
        [.editor],
        [.general, .shortcuts, .about],
    ]
}

/// A search hit: a page, or one setting on it.
struct SettingsSearchEntry: Identifiable {
    let title: String
    let page: SettingsPageID
    var isPage: Bool { title == page.title }
    var id: String { "\(page.rawValue):\(title)" }

    static func results(for query: String) -> [SettingsSearchEntry] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        return SettingsPageID.allCases.flatMap { page in
            ([page.title] + page.searchableSettings)
                .filter { $0.localized.localizedCaseInsensitiveContains(needle) }
                .map { SettingsSearchEntry(title: $0, page: page) }
        }
    }
}

@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPageID = .text
    /// The setting a search result pointed at: its page scrolls to it and lights it up for a moment, then this goes
    /// back to nil.
    var highlightedSetting: String?

    func open(_ entry: SettingsSearchEntry) {
        page = entry.page
        highlightedSetting = entry.isPage ? nil : entry.title
    }
}

/// Owns the single settings window, so the menu bar, the prompter and the Scripts window all open the same one.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    /// Fires when the window closes. The app delegate uses it to drop back to a menu-bar-only app when the last
    /// user window goes away.
    var onClose: (() -> Void)?

    var isOpen: Bool { window != nil }

    func show(_ page: SettingsPageID? = nil) {
        if let page { navigation.page = page }
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = String(localized: "window_title_settings")
            // A full-size content view so the sidebar runs up to the top of the window with the traffic lights sitting
            // on it, the way System Settings has it.
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 720, height: 480)
            window.contentViewController = NSHostingController(
                rootView: SettingsWindowView()
                    .environment(navigation))
            window.setContentSize(NSSize(width: 820, height: 600))
            window.center()
            window.setFrameAutosaveName("NotchySettings")
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

/// The sidebar on the left, running the full height of the window, and the selected page on the right.
struct SettingsWindowView: View {
    @Environment(SettingsNavigation.self) private var navigation

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar()
                .frame(width: 220)
                .ignoresSafeArea(.container, edges: .top)
            Group {
                switch navigation.page {
                case .text: TextSettingsPage()
                case .scrolling: ScrollingSettingsPage()
                case .voice: VoiceSettingsPage()
                case .notch: NotchSettingsPage()
                case .editor: EditorSettingsPage()
                case .general: GeneralSettingsPage()
                case .shortcuts: ShortcutsSettingsPage()
                case .about: AboutSettingsPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }
}

/// System Settings' sidebar: search on top, the pages under it, the window's wallpaper showing faintly through.
private struct SettingsSidebar: View {
    @Environment(SettingsNavigation.self) private var navigation
    @State private var query = ""
    @FocusState private var isSearching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                // Clears the traffic lights, which sit on the sidebar.
                .padding(.top, 44)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        pages
                    } else {
                        results
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.never)
            footer
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background { SidebarMaterial() }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1)
        }
        // ⌘F from anywhere in the window, as in System Settings.
        .background {
            Button("") { isSearching = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(String(localized: "settings_search"), text: $query)
                .textFieldStyle(.plain)
                .focused($isSearching)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(
            Capsule().fill(Color.primary.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
        )
    }

    @ViewBuilder
    private var pages: some View {
        ForEach(Array(SettingsPageID.sections.enumerated()), id: \.offset) { index, section in
            if index > 0 {
                // Groups apart by a gap, not a heading, like System Settings.
                Spacer().frame(height: 14)
            }
            ForEach(section) { page in
                SidebarRow(page: page, isSelected: navigation.page == page) {
                    navigation.page = page
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        let found = SettingsSearchEntry.results(for: query)
        if found.isEmpty {
            Text(String(localized: "settings_no_results"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        }
        // Grouped under the page they are on, in the sidebar's own order.
        ForEach(SettingsPageID.allCases) { page in
            let onPage = found.filter { $0.page == page }
            if !onPage.isEmpty {
                SidebarRow(page: page, isSelected: false) {
                    navigation.open(SettingsSearchEntry(title: page.title, page: page))
                }
                ForEach(onPage.filter { !$0.isPage }) { entry in
                    Button {
                        navigation.open(entry)
                    } label: {
                        Text(entry.title.localized)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 42)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer().frame(height: 6)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(SettingsPalette.selection)
            Text(String(localized: "settings_footer_privacy"))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One page in the sidebar: colored icon and name, filled with the accent color while it is the one open.
private struct SidebarRow: View {
    let page: SettingsPageID
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: page.symbol, color: page.color, size: 24)
                Text(page.title.localized)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The sidebar's glass: the desktop behind the window shows through, softened.
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
