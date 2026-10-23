import KnowWhereAmICore
import SwiftUI

/// A manuscript as a folded sheet of paper. Cards are content, not controls,
/// so they stay opaque paper rather than Liquid Glass.
struct ScriptCard: View {
    let script: Manuscript
    let selected: Bool
    let lastRun: RehearsalRecord?
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var words: Int { ScriptDocument.wordCount(in: script.content.text) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 9) {
                    badge
                    Text(script.content.title)
                        .font(.display(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(3)
                    Text(String(script.content.text.prefix(220)).replacingOccurrences(of: "\n", with: " "))
                        .font(.display(.footnote)).foregroundStyle(.secondary)
                        .lineSpacing(2).lineLimit(4)
                    Spacer(minLength: 8)
                    footer.padding(.trailing, 36)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
                .padding(16)
                .background {
                    FoldedSheet().fill(Theme.sheet)
                        .shadow(color: .black.opacity(selected ? 0.08 : 0.05), radius: selected ? 18 : 12, y: 6)
                }
                .overlay {
                    FoldedSheet().strokeBorder(selected ? Theme.accent.opacity(0.6) : Theme.hairline,
                                               lineWidth: selected ? 1.25 : 0.75)
                }
                .overlay(alignment: .topTrailing) {
                    FoldFlap().fill(Theme.raised).frame(width: FoldedSheet.fold, height: FoldedSheet.fold)
                }
            }
            .buttonStyle(ReaderControlStyle(pressedScale: 0.975))
            .accessibilityIdentifier("manuscript-\(script.id.uuidString)")
            .accessibilityAddTraits(selected ? .isSelected : [])
            Menu {
                Button("Edit", systemImage: "square.and.pencil", action: onEdit)
                Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.track, in: Circle())
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            // The circle's edges sit on the card's 16 pt content margins.
            .padding(8).accessibilityLabel("Actions for \(script.content.title)")
        }
    }

    @ViewBuilder private var badge: some View {
        if selected {
            Label("Reading", systemImage: "book.pages.fill")
                .font(.caption2.weight(.bold)).tracking(0.6).textCase(.uppercase)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Theme.accent.opacity(0.12), in: Capsule())
                // Optical alignment: the label, not the capsule, lines up with the title.
                .padding(.leading, -8)
        } else {
            Text("Edited \(Text(script.modifiedAt, format: .relative(presentation: .named)))")
                .font(.caption2.weight(.medium)).foregroundStyle(.tertiary)
                .padding(.vertical, 4)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(words) \(words == 1 ? "word" : "words")")
                    .font(.caption.weight(.medium).monospacedDigit()).foregroundStyle(Theme.ink.opacity(0.7))
                Text(words == 0 ? "Empty" : "\(ReadingLength.minutes(words: words)) min aloud")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            if let lastRun {
                HStack(spacing: 6) {
                    MatchDial(matched: lastRun.statistics.matchedWords, missed: lastRun.statistics.missedWords,
                              diameter: 14, lineWidth: 2.5, showsValue: false)
                    Text(lastRun.statistics.accuracy.map { "\(Int(($0 * 100).rounded()))% last run" } ?? "Rehearsed")
                        .font(.caption.weight(.medium)).foregroundStyle(Theme.ink.opacity(0.75))
                }
            }
        }
    }
}
