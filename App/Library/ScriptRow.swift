import KnowWhereAmICore
import SwiftUI

/// A manuscript in the list, styled after Notes: title, date and first line,
/// then length and the last run's match.
struct ScriptRow: View {
    let script: Manuscript
    let selected: Bool
    let lastRun: RehearsalRecord?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var words: Int { ScriptDocument.wordCount(in: script.content.text) }
    private var firstLine: String {
        script.content.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "No text"
    }
    private var details: String {
        var parts = ["\(words) \(words == 1 ? "word" : "words")"]
        if words > 0 { parts.append("\(ReadingLength.minutes(words: words)) min aloud") }
        if let accuracy = lastRun?.statistics.accuracy { parts.append("\(Int((accuracy * 100).rounded()))% last match") }
        return parts.joined(separator: " \u{00B7} ")
    }

    var body: some View {
        // List buttons tint their labels, so colors here are concrete, not hierarchical.
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(script.content.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                if typeSize.isAccessibilitySize {
                    Text(script.modifiedAt, format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Color.primary)
                    Text(firstLine).foregroundStyle(Color.secondary).lineLimit(2)
                } else {
                    Text("\(Text(script.modifiedAt, format: .dateTime.month(.abbreviated).day()).foregroundStyle(Color.primary))  \(firstLine)")
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 1)
            }
            .font(.subheadline)
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
