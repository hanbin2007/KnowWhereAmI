import KnowWhereAmICore
import SwiftUI

/// A Storage-style stacked bar: matched, missed, and not assessed.
struct CoverageBar: View {
    let stats: RehearsalStatistics
    let wordCount: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    private var segments: [(count: Int, color: Color)] {
        [(stats.matchedWords, RehearsalColor.matched), (stats.missedWords, RehearsalColor.missed),
         (max(0, wordCount - stats.assessedWords), RehearsalColor.unassessed)].filter { $0.count > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Manuscript").font(.headline)
                Spacer()
                Text("\(stats.assessedWords) of \(wordCount) Words Assessed")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            GeometryReader { geometry in
                let gaps = CGFloat(max(0, segments.count - 1)) * 2
                HStack(spacing: 2) {
                    ForEach(segments.indices, id: \.self) { index in
                        Rectangle()
                            .fill(segments[index].color)
                            .frame(width: max(2, (geometry.size.width - gaps) * CGFloat(segments[index].count) / CGFloat(max(1, wordCount))))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            let legend = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                                                     : AnyLayout(HStackLayout(spacing: 14))
            legend {
                key("Matched", color: RehearsalColor.matched)
                key("Missed", color: RehearsalColor.missed)
                key("Not Assessed", color: RehearsalColor.unassessed)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Manuscript coverage")
        .accessibilityValue("\(stats.matchedWords) matched, \(stats.missedWords) estimated missed, \(max(0, wordCount - stats.assessedWords)) not assessed")
    }

    private func key(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}
