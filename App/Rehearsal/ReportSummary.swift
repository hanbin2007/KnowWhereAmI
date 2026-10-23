import KnowWhereAmICore
import SwiftUI

/// The headline row: an Activity-style ring beside the match percentage.
struct ReportSummary: View {
    let stats: RehearsalStatistics
    let revealed: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize = 72.0
    @Environment(\.dynamicTypeSize) private var typeSize

    private var percent: Int? { stats.accuracy.map { Int(($0 * 100).rounded()) } }

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                                 : AnyLayout(HStackLayout(spacing: 18))
        return layout {
            MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: min(ringSize, 120),
                      lineWidth: 10, showsValue: false, progress: revealed ? 1 : 0)
                .padding(5)
            VStack(alignment: .leading, spacing: 1) {
                Text("Script Match")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(percent.map(String.init) ?? "\u{2014}")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    if percent != nil {
                        Text("%").font(.system(.title2, design: .rounded, weight: .semibold))
                    }
                }
                .foregroundStyle(percent == nil ? Color.secondary : Theme.accent)
                Text(stats.assessedWords > 0 ? "\(stats.matchedWords) of \(stats.assessedWords) words heard as written"
                                             : "No finalized speech was matched")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(typeSize.isAccessibilitySize ? 4 : 2).minimumScaleFactor(0.8)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated script match")
        .accessibilityValue(percent.map { "\($0) percent, \(stats.matchedWords) of \(stats.assessedWords) assessed words" } ?? "Not assessed")
    }
}
