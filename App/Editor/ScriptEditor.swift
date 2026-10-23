import KnowWhereAmICore
import SwiftUI
import UniformTypeIdentifiers

struct ScriptEditor: View {
    let model: ReaderModel
    let isNew: Bool
    private let initialTitle: String
    private let initialText: String
    @State private var title: String
    @State private var text: String
    @State private var showsImporter = false
    @State private var importError: String?
    @State private var confirmsDiscard = false
    @State private var previousDraft: Draft?
    @ScaledMetric(relativeTo: .body) private var editorSize = 19.0
    @AppStorage(ReaderTypeface.storageKey) private var typeface = ReaderTypeface.serif
    @Environment(\.dismiss) private var dismiss

    init(model: ReaderModel, isNew: Bool = false) {
        self.model = model
        self.isNew = isNew
        initialTitle = isNew ? "" : model.saved.title
        initialText = isNew ? "" : model.saved.text
        _title = State(initialValue: initialTitle)
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Untitled script", text: $title)
                        .font(.display(.title, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .submitLabel(.done)
                        .accessibilityIdentifier("scriptTitleField")
                    HStack(spacing: 8) {
                        Text(ReadingLength.summary(words: wordCount))
                            .contentTransition(.numericText(value: Double(wordCount)))
                        if title.count > 80 {
                            notice("Title over 80 characters")
                        } else if text.utf16.count > ScriptStore.maximumTextLength {
                            notice("Script is too long")
                        }
                    }
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .calmAnimation(Motion.snappy, value: wordCount)
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 14)
                Rectangle().fill(Theme.hairline).frame(height: 0.75).padding(.horizontal, 24)
                    .accessibilityHidden(true)
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Start with the first sentence you\u{2019}ll say\u{2026}")
                            .font(.system(size: editorSize, design: typeface.design)).italic()
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 23).padding(.top, 20)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: editorSize, design: typeface.design))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(6)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .accessibilityLabel("Script text")
                        .accessibilityIdentifier("scriptBodyField")
                }
            }
            .background(Theme.paper)
            .navigationTitle(isNew ? "New script" : "Edit script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) {
                        if isDirty { confirmsDiscard = true } else { dismiss() }
                    }
                    .accessibilityIdentifier("cancelEditor")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if previousDraft != nil {
                            Button("Undo replacement", systemImage: "arrow.uturn.backward") {
                                if let draft = previousDraft {
                                    title = draft.title; text = draft.text; previousDraft = nil
                                }
                            }.accessibilityIdentifier("undoDraftReplacement")
                        }
                        Button("Import text file", systemImage: "doc.badge.plus") { showsImporter = true }
                        PasteButton(payloadType: String.self) { strings in
                            if let pasted = strings.first { replaceDraft(title: title, text: pasted) }
                        }
                        Button("Practice script", systemImage: "doc.text") {
                            replaceDraft(title: ReaderModel.practice.title, text: ReaderModel.practice.text)
                        }
                        Button("Clear text", systemImage: "trash", role: .destructive) { replaceDraft(title: title, text: "") }
                            .accessibilityIdentifier("clearDraft")
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Script actions")
                    .accessibilityIdentifier("editorActions")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        let saved = isNew ? model.createScript(title: title, text: text) : model.saveScript(title: title, text: text)
                        if saved { dismiss() }
                        else { importError = model.alert?.message; model.alert = nil }
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("saveScript")
                    .disabled(title.count > 80 || text.utf16.count > ScriptStore.maximumTextLength)
                }
            }
            .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 1_000_000 else { throw ScriptStorageError.scriptTooLong }
                    let data = try Data(contentsOf: url)
                    let imported = try ScriptTextImport.decode(data)
                    replaceDraft(title: String(url.deletingPathExtension().lastPathComponent.prefix(80)), text: imported)
                } catch {
                    importError = error.localizedDescription
                }
            }
            .alert("Couldn't update script", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
        .confirmationDialog("Discard changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
        }
        .interactiveDismissDisabled(isDirty)
    }

    private var isDirty: Bool { text != initialText || title != initialTitle }
    private var wordCount: Int { ScriptDocument.wordCount(in: text) }

    private func notice(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.missed)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
    }

    private func replaceDraft(title: String, text: String) {
        previousDraft = Draft(title: self.title, text: self.text)
        self.title = title
        self.text = text
    }

    private struct Draft { let title: String; let text: String }
}
