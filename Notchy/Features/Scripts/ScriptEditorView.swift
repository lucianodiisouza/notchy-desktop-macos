import SwiftUI
import AppKit

struct ScriptEditorView: View {
    @ObservedObject var store: ScriptStore
    let script: Script

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @FocusState private var titleFocused: Bool

    private var currentScript: Script? {
        store.scripts.first { $0.id == script.id }
    }

    var body: some View {
        if let s = currentScript {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Título", text: $title)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding()
                    .focused($titleFocused)
                    .onChange(of: title) { newValue in
                        store.updateScript(id: s.id, title: newValue, body: nil)
                    }

                Divider()

                ScriptBodyEditorView(text: $bodyText) { newValue in
                    store.updateScript(id: s.id, title: nil, body: newValue)
                }
                .padding()
            }
            .onAppear {
                title = s.title
                bodyText = s.body
            }
            .onChange(of: s.title) { newValue in
                if title != newValue { title = newValue }
            }
            .onChange(of: s.body) { newValue in
                if bodyText != newValue { bodyText = newValue }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Usar no Teleprompter") {
                        store.selectScript(id: s.id)
                        ScriptStore.openTeleprompterInMainApp()
                    }
                    .disabled(store.selectedScriptId == s.id)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Roteiro não encontrado")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Multiline text editor that reports changes (debounced) to the store.
struct ScriptBodyEditorView: View {
    @Binding var text: String
    var onCommit: (String) -> Void

    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .onChange(of: text) { newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        onCommit(newValue)
                    }
                }
            }
            .onDisappear {
                debounceTask?.cancel()
                onCommit(text)
            }
    }
}
