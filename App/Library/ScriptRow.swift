import KnowWhereAmICore
import SwiftUI

/// A manuscript in the list, styled after Notes: title, date and first line,
/// then length and the last run's match.
struct ScriptRow: View {
    let script: Manuscript
    let selected: Bool
    let lastRun: RehearsalRecord?

    private var words: Int { ScriptDocument.wordCount(in: script.content.text) }
    private var firstLine: String {
        script.content.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "No text"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(script.content.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(Text(script.modifiedAt, format: .dateTime.month(.abbreviated).day()).foregroundStyle(.primary))  \(firstLine)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label("\(words) \(words == 1 ? "word" : "words")", systemImage: "text.alignleft")
                    if words > 0 {
                        Label("\(ReadingLength.minutes(words: words)) min", systemImage: "clock")
                    }
                    if let accuracy = lastRun?.statistics.accuracy {
                        Label("\(Int((accuracy * 100).rounded()))%", systemImage: "checkmark.circle")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .padding(.top, 2)
            }
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
