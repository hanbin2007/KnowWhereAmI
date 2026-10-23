import KnowWhereAmICore
import SwiftUI

/// Active time, pace, and words spoken as three tiles.
struct ReportMetrics: View {
    let stats: RehearsalStatistics
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            tile(symbol: "timer", value: ReaderChrome.time(stats.elapsedSeconds), unit: nil, label: "Active time")
            tile(symbol: "gauge.with.dots.needle.33percent",
                 value: stats.wordsPerMinute.map { "\(Int($0.rounded()))" } ?? "--", unit: "wpm",
                 label: stats.wordsPerMinute.map { PaceBand(wordsPerMinute: $0).title } ?? "Pace")
            tile(symbol: "text.word.spacing", value: "\(stats.spokenWords)", unit: nil, label: "Words spoken")
        }
    }

    private func tile(symbol: String, value: String, unit: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.figure(.title2, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.ink)
                    if let unit { Text(unit).font(.caption.weight(.medium)).foregroundStyle(.secondary) }
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheetSurface(radius: 18)
        .accessibilityElement(children: .combine)
    }
}
