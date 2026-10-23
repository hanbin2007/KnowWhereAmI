import KnowWhereAmICore
import SwiftUI

/// Workout-style details: a label above each large rounded value.
struct ReportMetricGrid: View {
    let stats: RehearsalStatistics
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                activeTime
                Divider()
                pace
                Divider()
                spoken
                Divider()
                missed
            }
            .padding(.vertical, 6)
        } else {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow { activeTime; pace }
                Divider()
                GridRow { spoken; missed }
            }
            .padding(.vertical, 6)
        }
    }

    private var activeTime: some View { metric("Active Time", value: ReaderChrome.time(stats.elapsedSeconds)) }
    private var pace: some View {
        metric("Average Pace", value: stats.wordsPerMinute.map { "\(Int($0.rounded()))" } ?? "\u{2014}",
               unit: stats.wordsPerMinute == nil ? nil : "WPM")
    }
    private var spoken: some View { metric("Words Spoken", value: "\(stats.spokenWords)") }
    private var missed: some View {
        metric("Est. Missed", value: "\(stats.missedWords)", tint: stats.missedWords > 0 ? Theme.missed : .primary)
    }

    private func metric(_ title: String, value: String, unit: String? = nil, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
                if let unit {
                    Text(unit).font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
            }
            .foregroundStyle(tint)
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
