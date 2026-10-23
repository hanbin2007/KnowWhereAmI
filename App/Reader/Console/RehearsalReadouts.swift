import KnowWhereAmICore
import SwiftUI

/// Live pace and match, set like Fitness workout metrics: a small label over a
/// large rounded value with its unit.
struct RehearsalReadouts: View {
    let model: ReaderModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: model.phase != .listening)) { _ in
            let stats = model.statistics
            HStack(alignment: .top, spacing: 16) {
                metric("Pace", value: stats.wordsPerMinute.map { "\(Int($0.rounded()))" },
                       unit: "WPM", detail: stats.wordsPerMinute.map { PaceBand(wordsPerMinute: $0).title })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Words per minute: \(stats.wordsPerMinute.map { String(Int($0.rounded())) } ?? "Not available")")
                    .accessibilityIdentifier("rehearsalMetrics")
                metric("Match", value: stats.accuracy.map { "\(Int(($0 * 100).rounded()))" },
                       unit: "%", detail: stats.assessedWords > 0 ? (stats.missedWords == 0 ? "None missed" : "\(stats.missedWords) missed") : nil,
                       tint: Theme.accent)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Estimated script match: \(stats.accuracy.map { "\(Int(($0 * 100).rounded())) percent, \(stats.missedWords) estimated missed words" } ?? "Not assessed")")
            }
            .calmAnimation(Motion.gentle, value: stats.spokenWords)
        }
    }

    private func metric(_ title: String, value: String?, unit: String, detail: String?, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value ?? "\u{2014}")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if value != nil {
                    Text(unit).font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
            }
            .foregroundStyle(value == nil ? Color.secondary : tint)
            Text(detail ?? " ")
                .font(.footnote).foregroundStyle(.secondary)
                .contentTransition(.interpolate)
        }
        .lineLimit(1).minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
