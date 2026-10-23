import KnowWhereAmICore
import SwiftUI

/// Pace and match, each a dial with a plain-language caption.
struct RehearsalReadouts: View {
    let model: ReaderModel
    @ScaledMetric(relativeTo: .body) private var dialSize = 56.0
    @Environment(\.dynamicTypeSize) private var typeSize
    private var dial: CGFloat { min(dialSize, 84) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: model.phase != .listening)) { _ in
            let stats = model.statistics
            HStack(spacing: 14) {
                readout(title: "Pace", detail: stats.wordsPerMinute.map { PaceBand(wordsPerMinute: $0).title } ?? "Waiting") {
                    PaceDial(wordsPerMinute: stats.wordsPerMinute, diameter: dial)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Words per minute: \(stats.wordsPerMinute.map { String(Int($0.rounded())) } ?? "Not available")")
                .accessibilityIdentifier("rehearsalMetrics")
                Rectangle().fill(Theme.hairline).frame(width: 0.75, height: dial * 0.7).accessibilityHidden(true)
                readout(title: "Match", detail: matchDetail(stats)) {
                    MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: dial)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Estimated script match: \(stats.accuracy.map { "\(Int(($0 * 100).rounded())) percent, \(stats.missedWords) estimated missed words" } ?? "Not assessed")")
            }
            .calmAnimation(Motion.gentle, value: stats.spokenWords)
        }
    }

    /// Dial beside its caption; at accessibility sizes the caption moves below
    /// the dial so neither has to wrap mid-word.
    private func readout<Dial: View>(title: String, detail: String, @ViewBuilder dial: () -> Dial) -> some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            dial()
            VStack(alignment: stacked ? .center : .leading, spacing: 2) {
                if !stacked {
                    Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Text(detail).font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.interpolate)
            }
        }
        .frame(maxWidth: .infinity, alignment: stacked ? .center : .leading)
    }

    private func matchDetail(_ stats: RehearsalStatistics) -> String {
        guard stats.assessedWords > 0 else { return "Not yet" }
        return stats.missedWords == 0 ? "Nothing missed" : "\(stats.missedWords) est. missed"
    }
}
