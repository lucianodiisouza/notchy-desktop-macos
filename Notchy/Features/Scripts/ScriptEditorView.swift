import SwiftUI
import AppKit

// Editor estilo Notion: blocos editáveis. Tabela = grade que o usuário vê e edita.
// Persistência em Markdown; teleprompter usa MarkdownHelpers.plainText(from:).

struct ScriptEditorView: View {
    @ObservedObject var store: ScriptStore
    let script: Script
    var onOpenSettings: (() -> Void)? = nil

    @AppStorage(NotchyKeys.scriptEditorFontSize) private var editorFontSize: Double = 14
    @AppStorage(NotchyKeys.scriptEditorTheme) private var themeRaw: Int = 0
    @AppStorage(NotchyKeys.scriptEditorLineSpacing) private var lineSpacing: Double = 1.2
    @AppStorage(NotchyKeys.scriptEditorFontName) private var fontName: String = ""
    @State private var title: String = ""
    @State private var blocks: [ScriptBlock] = []
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
                TextField("Título", text: $title)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding()
                    .focused($titleFocused)
                    .onChange(of: title) { newValue in
                        store.updateScript(id: s.id, title: newValue, body: nil)
                    }

                Divider()

                BlocksToolbar(onAddParagraph: { appendBlock(.paragraph("")) },
                             onAddHeading: { appendBlock(.heading(2, "")) },
                             onAddBulletedList: { appendBlock(.bulletedList([""])) },
                             onAddNumberedList: { appendBlock(.numberedList([""])) },
                             onAddTable: { appendBlock(.table(rows: [["Coluna 1", "Coluna 2"], ["", ""]])) },
                             onOpenSettings: onOpenSettings)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(blocks.indices, id: \.self) { index in
                            BlockRowView(
                                block: blockBinding(at: index),
                                fontSize: editorFontSize,
                                fontName: fontName.isEmpty ? nil : fontName,
                                lineSpacing: lineSpacing,
                                onDelete: blocks.count > 1 ? { deleteBlock(at: index) } : nil
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 200)
            }
            .onAppear {
                title = s.title
                let parsed = ScriptBlock.parse(markdown: s.body)
                blocks = parsed.isEmpty ? [.paragraph("")] : parsed
                AppLogger.scriptEditorDidOpen(scriptId: s.id.uuidString, title: s.title, bodyLength: s.body.count)
            }
            .onChange(of: s.title) { newValue in
                if title != newValue { title = newValue }
            }
            .onChange(of: s.body) { newValue in
                let parsed = ScriptBlock.parse(markdown: newValue)
                if parsed != blocks { blocks = parsed.isEmpty ? [.paragraph("")] : parsed }
            }
            .onChange(of: blocks) { _ in
                commitBlocks()
            }
            .preferredColorScheme(colorScheme)
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
            .onAppear { AppLogger.scriptEditorScriptNotFound(scriptId: script.id.uuidString) }
        }
    }

    private func blockBinding(at index: Int) -> Binding<ScriptBlock> {
        Binding(
            get: { blocks.indices.contains(index) ? blocks[index] : .paragraph("") },
            set: { newBlock in
                guard index < blocks.count else { return }
                var b = blocks
                b[index] = newBlock
                blocks = b
            }
        )
    }

    private func appendBlock(_ block: ScriptBlock) {
        blocks.append(block)
    }

    private func deleteBlock(at index: Int) {
        guard index < blocks.count else { return }
        blocks.remove(at: index)
    }

    private func commitBlocks() {
        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let s = currentScript else { return }
            await MainActor.run {
                let markdown = ScriptBlock.toMarkdown(blocks)
                AppLogger.scriptEditorDidCommitBody(scriptId: s.id.uuidString, bodyLength: markdown.count)
                store.updateScript(id: s.id, title: nil, body: markdown, bodyRTF: nil, clearRTF: true)
            }
        }
    }
}

private let scriptEditorApplyFormatWrapName = Notification.Name("scriptEditorApplyFormatWrap")

private func postFormatWrap(prefix: String, suffix: String) {
    NotificationCenter.default.post(
        name: scriptEditorApplyFormatWrapName,
        object: nil,
        userInfo: ["prefix": prefix, "suffix": suffix]
    )
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

// MARK: - Toolbar (inserir blocos + formatação)

private struct BlocksToolbar: View {
    let onAddParagraph: () -> Void
    let onAddHeading: () -> Void
    let onAddBulletedList: () -> Void
    let onAddNumberedList: () -> Void
    let onAddTable: () -> Void
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Button("Texto") { onAddParagraph() }.buttonStyle(.borderless).help("Parágrafo")
            Button("Título") { onAddHeading() }.buttonStyle(.borderless).help("Título")
            Button("Lista") { onAddBulletedList() }.buttonStyle(.borderless).help("Lista com marcadores")
            Button("1. Lista") { onAddNumberedList() }.buttonStyle(.borderless).help("Lista numerada")
            Divider().frame(height: 16)
            Button("Tabela") { onAddTable() }.buttonStyle(.borderless).help("Inserir tabela")
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                FormatButton(icon: "bold", action: { postFormatWrap(prefix: "**", suffix: "**") })
                    .help("Negrito (⌘B)")
                FormatButton(icon: "italic", action: { postFormatWrap(prefix: "*", suffix: "*") })
                    .help("Itálico (⌘I)")
                FormatButton(icon: "underline", action: { postFormatWrap(prefix: "%", suffix: "%") })
                    .help("Sublinhado")
                Menu {
                    Button("Pequeno (12 pt)") { postFormatWrap(prefix: "[12]", suffix: "[/12]") }
                    Button("Normal (14 pt)") { postFormatWrap(prefix: "[14]", suffix: "[/14]") }
                    Button("Grande (18 pt)") { postFormatWrap(prefix: "[18]", suffix: "[/18]") }
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Tamanho da fonte")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            if let onOpenSettings = onOpenSettings {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Configurações do editor")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Uma linha de bloco (parágrafo, título, lista ou tabela)

private struct BlockRowView: View {
    @Binding var block: ScriptBlock
    var fontSize: Double
    var fontName: String?
    var lineSpacing: Double
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                switch block {
                case .paragraph:
                    ParagraphBlockView(text: paragraphBinding, fontSize: fontSize, fontName: fontName)
                        .frame(minHeight: 24)
                case .heading(let level, _):
                    HeadingBlockView(level: level, text: headingBinding, fontSize: fontSize, fontName: fontName)
                case .bulletedList:
                    BulletedListBlockView(items: bulletedBinding, fontSize: fontSize, fontName: fontName)
                case .numberedList:
                    NumberedListBlockView(items: numberedBinding, fontSize: fontSize, fontName: fontName)
                case .table:
                    TableBlockView(rows: tableBinding, fontSize: fontSize, fontName: fontName)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if onDelete != nil {
                Button(action: { onDelete?() }) {
                    Image(systemName: "trash")
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remover bloco")
            }
        }
    }

    private var paragraphBinding: Binding<String> {
        Binding(get: { if case .paragraph(let t) = block { return t }; return "" },
                set: { block = .paragraph($0) })
    }

    private var headingBinding: Binding<String> {
        Binding(get: { if case .heading(_, let t) = block { return t }; return "" },
                set: { if case .heading(let l, _) = block { block = .heading(l, $0) } })
    }

    private var bulletedBinding: Binding<[String]> {
        Binding(get: { if case .bulletedList(let i) = block { return i }; return [] },
                set: { block = .bulletedList($0) })
    }

    private var numberedBinding: Binding<[String]> {
        Binding(get: { if case .numberedList(let i) = block { return i }; return [] },
                set: { block = .numberedList($0) })
    }

    private var tableBinding: Binding<[[String]]> {
        Binding(get: { if case .table(let r) = block { return r }; return [] },
                set: { block = .table(rows: $0) })
    }
}

// MARK: - Bloco parágrafo

private struct ParagraphBlockView: View {
    @Binding var text: String
    var fontSize: Double
    var fontName: String?

    var body: some View {
        TextEditor(text: $text)
            .font(fontName.flatMap { Font.custom($0, size: fontSize) } ?? .system(size: fontSize))
            .scrollContentBackground(.hidden)
            .frame(minHeight: 24)
    }
}

// MARK: - Bloco título

private struct HeadingBlockView: View {
    let level: Int
    @Binding var text: String
    var fontSize: Double
    var fontName: String?

    private var headingFont: Font {
        let size = fontSize + Double(4 - level) * 2
        return fontName.flatMap { Font.custom($0, size: max(size, 14)) } ?? .system(size: max(size, 14), weight: .semibold)
    }

    var body: some View {
        TextField("Título", text: $text)
            .font(headingFont)
            .textFieldStyle(.plain)
    }
}

// MARK: - Bloco lista com marcadores

private struct BulletedListBlockView: View {
    @Binding var items: [String]
    var fontSize: Double
    var fontName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").font(.system(size: fontSize)).foregroundStyle(.secondary)
                    TextField("Item", text: Binding(
                        get: { items.indices.contains(i) ? items[i] : "" },
                        set: { newVal in
                            var copy = items
                            while copy.count <= i { copy.append("") }
                            copy[i] = newVal
                            items = copy
                        }
                    ))
                    .font(fontName.flatMap { Font.custom($0, size: fontSize) } ?? .system(size: fontSize))
                    .textFieldStyle(.plain)
                }
            }
            Button("+ Item") {
                items = items + [""]
            }
            .buttonStyle(.borderless)
            .font(.system(size: fontSize - 1))
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bloco lista numerada

private struct NumberedListBlockView: View {
    @Binding var items: [String]
    var fontSize: Double
    var fontName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(i + 1).").font(.system(size: fontSize)).foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    TextField("Item", text: Binding(
                        get: { items.indices.contains(i) ? items[i] : "" },
                        set: { newVal in
                            var copy = items
                            while copy.count <= i { copy.append("") }
                            copy[i] = newVal
                            items = copy
                        }
                    ))
                    .font(fontName.flatMap { Font.custom($0, size: fontSize) } ?? .system(size: fontSize))
                    .textFieldStyle(.plain)
                }
            }
            Button("+ Item") {
                items = items + [""]
            }
            .buttonStyle(.borderless)
            .font(.system(size: fontSize - 1))
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bloco tabela (grade editável, estilo Notion)

private struct TableBlockView: View {
    @Binding var rows: [[String]]
    var fontSize: Double
    var fontName: String?

    private var columns: Int {
        rows.first?.count ?? 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cabeçalho + linhas
            if rows.isEmpty {
                Text("Tabela vazia").foregroundStyle(.secondary).padding(8)
            } else {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<columns, id: \.self) { colIndex in
                            TableCellView(
                                value: cellBinding(row: rowIndex, col: colIndex),
                                isHeader: rowIndex == 0,
                                fontSize: fontSize,
                                fontName: fontName
                            )
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }
            }

            HStack(spacing: 12) {
                Button("+ Linha") { addRow() }
                    .buttonStyle(.borderless)
                    .font(.system(size: fontSize - 1))
                Button("+ Coluna") { addColumn() }
                    .buttonStyle(.borderless)
                    .font(.system(size: fontSize - 1))
            }
            .padding(.top, 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .padding(1)
    }

    private func cellBinding(row: Int, col: Int) -> Binding<String> {
        Binding(
            get: {
                guard row < rows.count, col < rows[row].count else { return "" }
                return rows[row][col]
            },
            set: { newValue in
                guard row < rows.count else { return }
                var r = rows
                while r[row].count <= col {
                    r[row].append("")
                }
                r[row][col] = newValue
                rows = r
            }
        )
    }

    private func addRow() {
        let template = Array(repeating: "", count: columns)
        rows.append(template)
    }

    private func addColumn() {
        rows = rows.map { $0 + [""] }
    }
}

private struct TableCellView: View {
    @Binding var value: String
    var isHeader: Bool
    var fontSize: Double
    var fontName: String?

    var body: some View {
        TextField(isHeader ? "Cabeçalho" : "Celula", text: $value)
            .font(fontName.flatMap { Font.custom($0, size: fontSize) } ?? .system(size: fontSize, weight: isHeader ? .semibold : .regular))
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minWidth: 80, alignment: .leading)
            .background(isHeader ? Color(nsColor: .controlBackgroundColor).opacity(0.8) : Color.clear)
    }
}
