import SwiftUI

/// Paragraphs as proportional segments: spoken, current, and still ahead.
struct ParagraphRail: View {
    let starts: [Int]
    let wordCount: Int
    let cursor: Int?

    var body: some View {
        let current = starts.lastIndex(where: { $0 <= (cursor ?? 0) }) ?? 0
        GeometryReader { geometry in
            let gap = 3.0
            let usable = max(0, geometry.size.width - gap * Double(max(0, starts.count - 1)))
            HStack(spacing: gap) {
                ForEach(starts.indices, id: \.self) { index in
                    let end = index + 1 < starts.count ? starts[index + 1] : wordCount
                    let share = wordCount > 0 ? Double(end - starts[index]) / Double(wordCount) : 0
                    Capsule()
                        .fill(index < current ? Theme.accent.opacity(0.45) : index == current ? Theme.accent : Theme.track)
                        .frame(width: max(3, usable * share))
                }
            }
        }
        .frame(height: 4)
        .calmAnimation(Motion.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paragraph \(starts.isEmpty ? 0 : current + 1) of \(starts.count)")
        .accessibilityIdentifier("paragraphRail")
    }
}
