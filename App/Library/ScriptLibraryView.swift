import KnowWhereAmICore
import SwiftUI

struct ScriptLibraryView: View {
    let model: ReaderModel
    let onChoose: () -> Void
    let onNew: () -> Void
    let onEdit: () -> Void
    @State private var section = 0
    @State private var search = ""
    @State private var deletingScript: Manuscript?
    @State private var deletingRecord: RehearsalRecord?
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    private var scripts: [Manuscript] {
        model.library.manuscripts.filter {
            search.isEmpty || $0.content.title.localizedCaseInsensitiveContains(search) || $0.content.text.localizedCaseInsensitiveContains(search)
        }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    private var records: [RehearsalRecord] {
        model.history.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library view", selection: $section) {
                    Text("Scripts").tag(0)
                    Text("Rehearsals").tag(1)
                }
                .pickerStyle(.segmented).padding(.horizontal, 20).padding(.vertical, 12)
                .accessibilityIdentifier("librarySection")
                if section == 0 {
                    scriptList
                } else {
                    historyList
                }
            }
            .searchable(text: $search, prompt: section == 0 ? "Search scripts" : "Search rehearsals")
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("closeLibrary")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New script", systemImage: "plus", action: onNew)
                        .accessibilityIdentifier("newScript")
                }
            }
            .confirmationDialog("Delete script?", isPresented: Binding(get: { deletingScript != nil }, set: { if !$0 { deletingScript = nil } }), titleVisibility: .visible) {
                Button("Delete script", role: .destructive) {
                    if let deletingScript { perform { model.deleteManuscript(deletingScript.id) } }
                    deletingScript = nil
                }
            } message: { Text(deletingScript?.content.title ?? "") }
            .confirmationDialog("Delete rehearsal?", isPresented: Binding(get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } }), titleVisibility: .visible) {
                Button("Delete rehearsal", role: .destructive) {
                    if let deletingRecord { perform { model.deleteRehearsal(deletingRecord.id) } }
                    deletingRecord = nil
                }
            }
            .alert("Couldn't update library", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(failure ?? "") }
        }
    }

    private var scriptList: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                     count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                ForEach(scripts) { script in
                    scriptCard(script)
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if scripts.isEmpty {
                if !search.isEmpty { ContentUnavailableView.search(text: search) }
                else {
                    ContentUnavailableView {
                        Label("No scripts", systemImage: "doc.on.doc")
                    } actions: { Button("New script", systemImage: "plus", action: onNew) }
                }
            }
        }
    }

    private func scriptCard(_ script: Manuscript) -> some View {
        let selected = model.library.selectedID == script.id
        return ZStack(alignment: .bottomTrailing) {
            Button {
                perform { model.selectManuscript(script.id) }
                if failure == nil { onChoose() }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text").font(.system(size: 23, weight: .light))
                        Spacer()
                        if selected { Image(systemName: "checkmark.circle.fill").font(.subheadline) }
                    }
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    Text(script.content.title)
                        .font(.system(.title3, design: .serif, weight: .medium)).foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(String(script.content.text.prefix(160)).replacingOccurrences(of: "\n", with: " "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    Spacer(minLength: 4)
                    Text("\(ScriptDocument.wordCount(in: script.content.text)) words")
                        .font(.caption2).foregroundStyle(.secondary).padding(.trailing, 26)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 204, alignment: .topLeading)
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.6) : .primary.opacity(0.06), lineWidth: selected ? 1.5 : 0.5)
                }
            }
            .buttonStyle(ReaderControlStyle(pressedScale: 0.985))
            .accessibilityIdentifier("manuscript-\(script.id.uuidString)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            Menu {
                Button("Edit", systemImage: "square.and.pencil") {
                    perform { model.selectManuscript(script.id) }
                    if failure == nil { onEdit() }
                }
                Button("Duplicate", systemImage: "doc.on.doc") { perform { model.duplicateManuscript(script.id) } }
                Button("Delete", systemImage: "trash", role: .destructive) { deletingScript = script }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .padding(4).accessibilityLabel("Actions for \(script.content.title)")
        }
    }

    private var historyList: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    RehearsalReportView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(record.title).font(.body.weight(.medium)).lineLimit(2)
                        Text(record.endedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Text(ReaderChrome.time(record.statistics.elapsedSeconds))
                            if let rate = record.statistics.wordsPerMinute { Text("\(Int(rate.rounded())) WPM") }
                            Text(record.statistics.assessedWords > 0 ? "\(record.statistics.missedWords) est. missed" : "Not assessed")
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) { deletingRecord = record }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if records.isEmpty {
                if !search.isEmpty { ContentUnavailableView.search(text: search) }
                else { ContentUnavailableView("No rehearsals", systemImage: "clock.arrow.circlepath") }
            }
        }
    }

    private func perform(_ action: () -> Bool) {
        if !action() {
            failure = model.alert?.message ?? "The change could not be saved."
            model.alert = nil
        }
    }
}
