import KnowWhereAmICore
import SwiftUI

/// Manuscripts as an inset-grouped list with swipe actions and context menus.
struct ScriptList: View {
    let model: ReaderModel
    let scripts: [Manuscript]
    let searching: String
    let onOpen: (Manuscript) -> Void
    let onEdit: (Manuscript) -> Void
    let onDuplicate: (Manuscript) -> Void
    let onDelete: (Manuscript) -> Void
    let onNew: () -> Void

    var body: some View {
        List {
            ForEach(scripts) { script in
                let selected = model.library.selectedID == script.id
                Button { onOpen(script) } label: {
                    ScriptRow(script: script, selected: selected,
                              lastRun: model.history.first { $0.manuscriptID == script.id })
                }
                .accessibilityIdentifier("manuscript-\(script.id.uuidString)")
                .accessibilityLabel(script.content.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(script) }
                    Button("Duplicate", systemImage: "plus.square.on.square") { onDuplicate(script) }
                        .tint(.indigo)
                }
                .contextMenu {
                    Button("Edit", systemImage: "square.and.pencil") { onEdit(script) }
                    Button("Duplicate", systemImage: "plus.square.on.square") { onDuplicate(script) }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(script) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: scripts.map(\.id))
        .overlay {
            if scripts.isEmpty {
                if !searching.isEmpty { ContentUnavailableView.search(text: searching) }
                else {
                    ContentUnavailableView {
                        Label("No Scripts", systemImage: "text.page")
                    } description: {
                        Text("Scripts you write or import appear here.")
                    } actions: {
                        Button("New Script", action: onNew)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}
