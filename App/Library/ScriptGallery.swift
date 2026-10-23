import KnowWhereAmICore
import SwiftUI

/// Manuscripts as a two-column gallery of cards; one column at accessibility sizes.
struct ScriptGallery: View {
    let model: ReaderModel
    let scripts: [Manuscript]
    let searching: String
    let onOpen: (Manuscript) -> Void
    let onEdit: (Manuscript) -> Void
    let onDuplicate: (Manuscript) -> Void
    let onDelete: (Manuscript) -> Void
    let onNew: () -> Void
    @State private var appeared = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14),
                                     count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                ForEach(Array(scripts.enumerated()), id: \.element.id) { index, script in
                    ScriptCard(script: script, selected: model.library.selectedID == script.id,
                               lastRun: model.history.first { $0.manuscriptID == script.id },
                               onOpen: { onOpen(script) }, onEdit: { onEdit(script) },
                               onDuplicate: { onDuplicate(script) }, onDelete: { onDelete(script) })
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(reducedMotion ? nil : Motion.gentle.delay(Double(min(index, 8)) * 0.05), value: appeared)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24)
            .calmAnimation(Motion.morph, value: scripts.map(\.id))
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if scripts.isEmpty {
                if !searching.isEmpty { ContentUnavailableView.search(text: searching) }
                else {
                    ContentUnavailableView {
                        Label("No scripts yet", systemImage: "text.page")
                    } description: {
                        Text("Your manuscripts live here, ready for rehearsal or the stage.")
                    } actions: {
                        Button("New script", systemImage: "plus", action: onNew)
                            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    }
                }
            }
        }
        .onAppear {
            if reducedMotion { appeared = true } else { withAnimation(Motion.gentle) { appeared = true } }
        }
    }
}
