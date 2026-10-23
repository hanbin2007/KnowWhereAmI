import KnowWhereAmICore
import SwiftUI

/// The saved manuscript with matched, missed, and unassessed words marked.
struct ManuscriptReviewView: View {
    let record: RehearsalRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    legend("Matched", color: Theme.ink)
                    legend("Est. missed", color: RehearsalColor.missed)
                    legend("Not assessed", color: .secondary)
                }
                Text(reviewText)
                    .font(.display(.body)).lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(24)
        }
        .background(Theme.paper)
        .navigationTitle("Manuscript review").navigationBarTitleDisplayMode(.inline)
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    private var reviewText: AttributedString {
        let document = ScriptDocument(text: record.scriptText)
        let result = NSMutableAttributedString(string: record.scriptText, attributes: [.foregroundColor: UIColor.spokenInk])
        for index in record.statistics.matchedWordIndices where document.words.indices.contains(index) {
            result.addAttribute(.foregroundColor, value: UIColor.ink, range: document.words[index].range)
        }
        let missed = UIColor.dynamic(light: 0xBE4A2C, dark: 0xF07D5E)
        for index in record.statistics.omittedWordIndices where document.words.indices.contains(index) {
            result.addAttributes([.foregroundColor: missed,
                                  .backgroundColor: missed.withAlphaComponent(0.12),
                                  .underlineStyle: NSUnderlineStyle.single.rawValue,
                                  .underlineColor: missed.withAlphaComponent(0.5)], range: document.words[index].range)
        }
        return AttributedString(result)
    }
}
