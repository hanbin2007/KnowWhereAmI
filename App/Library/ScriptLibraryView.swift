import KnowWhereAmICore
import SwiftUI

/// Scripts and rehearsal history. Navigation, the section picker, and search
/// are all system controls, so they carry Liquid Glass and the scroll edge
/// effect; the cards and rows beneath them are content.
struct ScriptLibraryView: View {
    let model: ReaderModel
    let onChoose: () -> Void
    let onNew: () -> Void
    let onEdit: () -> Void
    @State private var section = LibrarySection.scripts
    @State private var search = ""
    @State private var deletingScript: Manuscript?
    @State private var deletingRecord: RehearsalRecord?
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss

    private enum LibrarySection: String, CaseIterable, Identifiable {
        case scripts = "Scripts", rehearsals = "Rehearsals"
        var id: String { rawValue }
    }

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
            ZStack {
                if section == .scripts {
                    ScriptList(model: model, scripts: scripts, searching: search,
                                  onOpen: { script in
                                      perform { model.selectManuscript(script.id) }
                                      if failure == nil { onChoose() }
                                  },
                                  onEdit: { script in
                                      perform { model.selectManuscript(script.id) }
                                      if failure == nil { onEdit() }
                                  },
                                  onDuplicate: { script in perform { model.duplicateManuscript(script.id) } },
                                  onDelete: { deletingScript = $0 },
                                  onNew: onNew)
                        .transition(.opacity)
                } else {
                    RehearsalHistoryList(records: records, searching: search) { deletingRecord = $0 }
                        .transition(.opacity)
                }
            }
            .safeAreaBar(edge: .top) {
                Picker("Library view", selection: $section) {
                    ForEach(LibrarySection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20).padding(.vertical, 8)
                .accessibilityIdentifier("librarySection")
            }
            .calmAnimation(Motion.morph, value: section)
            .searchable(text: $search, prompt: section == .scripts ? "Search scripts" : "Search rehearsals")
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel) { dismiss() }
                        .accessibilityIdentifier("closeLibrary")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Script", systemImage: "plus", action: onNew)
                        .accessibilityIdentifier("newScript")
                }
            }
            .confirmationDialog("Delete Script?", isPresented: Binding(get: { deletingScript != nil }, set: { if !$0 { deletingScript = nil } }), titleVisibility: .visible) {
                Button("Delete Script", role: .destructive) {
                    if let deletingScript { perform { model.deleteManuscript(deletingScript.id) } }
                    deletingScript = nil
                }
            } message: { Text(deletingScript?.content.title ?? "") }
            .confirmationDialog("Delete Rehearsal?", isPresented: Binding(get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } }), titleVisibility: .visible) {
                Button("Delete Rehearsal", role: .destructive) {
                    if let deletingRecord { perform { model.deleteRehearsal(deletingRecord.id) } }
                    deletingRecord = nil
                }
            }
            .alert("Couldn\u{2019}t Update Library", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(failure ?? "") }
        }
    }

    private func perform(_ action: () -> Bool) {
        if !action() {
            failure = model.alert?.message ?? "The change could not be saved."
            model.alert = nil
        }
    }
}
