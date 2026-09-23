import SwiftUI
import AppKit

// Editor com rich text em tempo real (negrito, itálico, sublinhado, tamanho). Persistência em RTF + body plain para o teleprompter.

struct ScriptEditorView: View {
    @ObservedObject var store: ScriptStore
    let script: Script

    @AppStorage(NotchyKeys.scriptEditorFontSize) private var editorFontSize: Double = 14
    @AppStorage(NotchyKeys.scriptEditorTheme) private var themeRaw: Int = 0
    @AppStorage(NotchyKeys.scriptEditorFontName) private var fontName: String = ""
    @State private var title: String = ""
    @State private var editingBody: String = ""
    @State private var editingRTF: Data?
    @State private var commitTask: Task<Void, Never>?
    @FocusState private var titleFocused: Bool

    private var currentScript: Script? {
        store.scripts.first { $0.id == script.id }
    }

    private var colorScheme: ColorScheme? {
        switch themeRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        if let s = currentScript {
            VStack(alignment: .leading, spacing: 0) {
                // Title and actions sit where a title bar would be; the empty part of this strip drags the window.
                HStack(alignment: .center, spacing: 10) {
                    TextField(String(localized: "field_title"), text: $title)
                        .font(.system(size: 22, weight: .bold))
                        .textFieldStyle(.plain)
                        .focused($titleFocused)
                        .onChange(of: title) { _, newValue in
                            store.updateScript(id: s.id, title: newValue, body: nil)
                        }
                    Spacer(minLength: 8)
                    Button {
                        _ = store.exportScriptAsTXT(id: s.id)
                    } label: {
                        Label(String(localized: "export_script"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .help(String(localized: "export_script_help"))
                    Button {
                        commitNow()
                        store.showInTeleprompter(id: s.id)
                    } label: {
                        Label(String(localized: "use_in_teleprompter"), systemImage: "text.aligncenter")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }
                .controlSize(.regular)
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 12)
                .background(WindowDragArea())

                FormatToolbar(editorFontSize: editorFontSize)

                RichParagraphEditorView(
                    body: $editingBody,
                    bodyRTF: $editingRTF,
                    fontSize: editorFontSize,
                    fontName: fontName.isEmpty ? nil : fontName
                )
                .frame(minHeight: 200)
            }
            .onAppear {
                title = s.title
                editingBody = s.body
                editingRTF = s.bodyRTF
            }
            .onChange(of: s.title) { _, newValue in
                if title != newValue { title = newValue }
            }
            .onChange(of: s.body) { _, newValue in
                if editingBody != newValue { editingBody = newValue }
            }
            .onChange(of: s.bodyRTF) { _, newValue in
                if editingRTF != newValue { editingRTF = newValue }
            }
            .onChange(of: editingBody) { _, _ in commitBody() }
            .onChange(of: editingRTF) { _, _ in commitBody() }
            // Switching scripts or closing the window saves what the 400 ms wait had not saved yet.
            .onDisappear { commitNow() }
            .preferredColorScheme(colorScheme)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(String(localized: "script_not_found"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func commitBody() {
        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { commitNow() }
        }
    }

    private func commitNow() {
        commitTask?.cancel()
        commitTask = nil
        guard let s = currentScript else { return }
        // No RTF means the text was cleared or is plain; drop the stored RTF so the old text does not come back.
        store.updateScript(id: s.id, title: nil, body: editingBody, bodyRTF: editingRTF, clearRTF: editingRTF == nil)
    }
}

private func postApplyFormat(_ format: ScriptEditorFormat, pointSize: Int? = nil) {
    var userInfo: [String: Any] = ["format": format.rawValue]
    if let size = pointSize { userInfo["pointSize"] = size }
    NotificationCenter.default.post(name: .scriptEditorApplyFormat, object: nil, userInfo: userInfo)
}

private struct FormatButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toolbar (só formatação básica)

private let fontSizeRange: ClosedRange<Double> = 8...36

private struct FormatToolbar: View {
    var editorFontSize: Double = 14

    @State private var sizePopover = false
    @State private var chosenSize: Double

    init(editorFontSize: Double = 14) {
        self.editorFontSize = editorFontSize
        _chosenSize = State(initialValue: editorFontSize)
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                FormatButton(icon: "bold", action: { postApplyFormat(.bold) })
                    .help(String(localized: "help_bold"))
                FormatButton(icon: "italic", action: { postApplyFormat(.italic) })
                    .help(String(localized: "help_italic"))
                FormatButton(icon: "underline", action: { postApplyFormat(.underline) })
                    .help(String(localized: "help_underline"))
                Button {
                    sizePopover = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $sizePopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "label_font_size_editor"))
                            .font(.headline)
                        HStack(spacing: 8) {
                            Slider(value: $chosenSize, in: fontSizeRange, step: 1)
                                .frame(width: 140)
                                .onChange(of: chosenSize) { _, newValue in
                                    postApplyFormat(.fontSize, pointSize: Int(newValue))
                                }
                            Text("\(Int(chosenSize)) pt")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                    .padding(12)
                    .frame(width: 200)
                }
                .onChange(of: editorFontSize) { _, newValue in
                    if !sizePopover { chosenSize = newValue }
                }
                .onChange(of: sizePopover) { _, isOpen in
                    if isOpen { chosenSize = editorFontSize }
                }
                .help(String(localized: "label_font_size_editor"))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color.primary.opacity(0.06))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
            )

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1) }
    }
}

/// Lets the empty part of a custom title strip move the window, like a real title bar.
private struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.performZoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
