import KnowWhereAmICore
import SwiftUI

/// Each estimated miss set back into its sentence.
struct MissedWordsSection: View {
    let record: RehearsalRecord
    let document: ScriptDocument
    private var stats: RehearsalStatistics { record.statistics }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Words to revisit")
                Spacer()
                if !stats.omittedWordIndices.isEmpty {
                    Text("\(stats.omittedWordIndices.count)")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(RehearsalColor.missed)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(RehearsalColor.missed.opacity(0.12), in: Capsule())
                }
            }
            if stats.omittedWordIndices.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: stats.assessedWords > 0 ? "checkmark.seal.fill" : "waveform.slash")
                        .font(.title2).foregroundStyle(stats.assessedWords > 0 ? Theme.accent : Color.secondary)
                    Text(stats.assessedWords > 0 ? "None in the text you reached." : "No scored speech in this run.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .sheetSurface(radius: 18)
            } else {
                ForEach(stats.omittedWordIndices, id: \.self) { index in
                    if document.words.indices.contains(index) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Word \(index + 1)")
                                Spacer()
                                Text("\(Int((Double(index + 1) / Double(document.words.count) * 100).rounded()))% through")
                            }
                            .font(.caption2.weight(.medium).monospacedDigit()).foregroundStyle(.tertiary)
                            Text(context(around: index))
                                .font(.display(.body)).lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sheetSurface(radius: 18)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Missed \(document.words[index].text), word \(index + 1)")
                    }
                }
            }
        }
    }

    /// A few words either side, with the missed word set in the miss color.
    private func context(around index: Int) -> AttributedString {
        let words = document.words
        let text = record.scriptText as NSString
        let firstWord = max(0, index - 5)
        let lastWord = min(words.count - 1, index + 6)
        let target = words[index].range
        let before = text.substring(with: NSRange(location: words[firstWord].range.location,
                                                  length: target.location - words[firstWord].range.location))
        let afterStart = NSMaxRange(target)
        let after = text.substring(with: NSRange(location: afterStart, length: NSMaxRange(words[lastWord].range) - afterStart))
        var result = AttributedString((firstWord > 0 ? "\u{2026}" : "") + before.replacingOccurrences(of: "\n", with: " "))
        result.foregroundColor = .secondary
        var word = AttributedString(text.substring(with: target))
        word.foregroundColor = RehearsalColor.missed
        word.font = .display(.body, weight: .semibold)
        word.underlineStyle = Text.LineStyle(pattern: .solid, color: RehearsalColor.missed.opacity(0.5))
        var tail = AttributedString(after.replacingOccurrences(of: "\n", with: " ") + (lastWord < words.count - 1 ? "\u{2026}" : ""))
        tail.foregroundColor = .secondary
        result.append(word)
        result.append(tail)
        return result
    }
}
