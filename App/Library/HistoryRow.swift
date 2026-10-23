import KnowWhereAmICore
import SwiftUI

/// One rehearsal in the timeline: its match ring, title, and pace.
struct HistoryRow: View {
    let record: RehearsalRecord
    private var stats: RehearsalStatistics { record.statistics }

    var body: some View {
        HStack(spacing: 14) {
            MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: 46, lineWidth: 3.5, showsValue: false)
                .overlay {
                    Text(stats.accuracy.map { "\(Int(($0 * 100).rounded()))" } ?? "\u{2014}")
                        .font(.figure(.footnote, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(stats.accuracy == nil ? .tertiary : .primary)
                        .minimumScaleFactor(0.6)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.display(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(details)
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var details: String {
        var parts = [record.endedAt.formatted(date: .omitted, time: .shortened), ReaderChrome.time(stats.elapsedSeconds)]
        if let rate = stats.wordsPerMinute { parts.append("\(Int(rate.rounded())) wpm") }
        if stats.assessedWords > 0 { parts.append(stats.missedWords == 0 ? "nothing missed" : "\(stats.missedWords) missed") }
        return parts.joined(separator: " \u{00B7} ")
    }
}
