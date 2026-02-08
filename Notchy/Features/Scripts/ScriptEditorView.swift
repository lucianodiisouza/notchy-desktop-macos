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
                TextField(String(localized: "field_title"), text: $title)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding()
                    .focused($titleFocused)
                    .onChange(of: title) { newValue in
                        store.updateScript(id: s.id, title: newValue, body: nil)
                    }

                Divider()

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
                AppLogger.scriptEditorDidOpen(scriptId: s.id.uuidString, title: s.title, bodyLength: s.body.count)
            }
            .onChange(of: s.title) { newValue in
                if title != newValue { title = newValue }
            }
            .onChange(of: s.body) { newValue in
                if editingBody != newValue { editingBody = newValue }
            }
            .onChange(of: s.bodyRTF) { newValue in
                if editingRTF != newValue { editingRTF = newValue }
            }
            .onChange(of: editingBody) { _ in commitBody() }
            .onChange(of: editingRTF) { _ in commitBody() }
            .preferredColorScheme(colorScheme)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(String(localized: "export_script")) {
                        _ = store.exportScriptAsTXT(id: s.id)
                    }
                    .help(String(localized: "export_script_help"))
                    Button(String(localized: "use_in_teleprompter")) {
                        store.selectScript(id: s.id)
                        ScriptStore.openTeleprompterInMainApp()
                    }
                }
            }
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
            .onAppear { AppLogger.scriptEditorScriptNotFound(scriptId: script.id.uuidString) }
        }
    }

    private func commitBody() {
        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let s = currentScript else { return }
            await MainActor.run {
                AppLogger.scriptEditorDidCommitBody(scriptId: s.id.uuidString, bodyLength: editingBody.count)
                store.updateScript(id: s.id, title: nil, body: editingBody, bodyRTF: editingRTF, clearRTF: false)
            }
        }
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
                                .onChange(of: chosenSize) { newValue in
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
                .onChange(of: editorFontSize) { newValue in
                    if !sizePopover { chosenSize = newValue }
                }
                .onChange(of: sizePopover) { isOpen in
                    if isOpen { chosenSize = editorFontSize }
                }
                .help(String(localized: "label_font_size_editor"))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }
}
