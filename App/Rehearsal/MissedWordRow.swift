import KnowWhereAmICore
import SwiftUI

/// One estimated miss: the word, its position, and the sentence around it.
struct MissedWordRow: View {
    let index: Int
    let document: ScriptDocument
    let scriptText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(document.words[index].text)
                    .font(.headline)
                    .foregroundStyle(Theme.missed)
                Spacer()
                Text("Word \(index + 1)")
                    .font(.subheadline).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(context)
                .font(.subheadline)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Missed \(document.words[index].text), word \(index + 1)")
        .accessibilityValue(String(context.characters))
    }

    /// A few words either side, with the missed word in the primary color.
    private var context: AttributedString {
        let words = document.words
        let text = scriptText as NSString
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
        word.foregroundColor = .primary
        word.font = .subheadline.weight(.semibold)
        var tail = AttributedString(after.replacingOccurrences(of: "\n", with: " ") + (lastWord < words.count - 1 ? "\u{2026}" : ""))
        tail.foregroundColor = .secondary
        result.append(word)
        result.append(tail)
        return result
    }
}
