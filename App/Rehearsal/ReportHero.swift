import KnowWhereAmICore
import SwiftUI

/// The match ring drawing itself in, with a written verdict and legend.
struct ReportHero: View {
    let stats: RehearsalStatistics
    let revealed: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 22) {
            MatchRing(matched: stats.matchedWords, missed: stats.missedWords, progress: revealed ? 1 : 0,
                      diameter: typeSize.isAccessibilitySize ? 220 : 196)
            VStack(spacing: 8) {
                Text(verdict)
                    .font(.display(.title2, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(narrative)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(revealed ? 1 : 0).offset(y: revealed ? 0 : 8)
            let legend = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            legend {
                chip("\(stats.matchedWords) matched", color: RehearsalColor.matched)
                chip("\(stats.missedWords) est. missed", color: RehearsalColor.missed)
                chip("\(stats.assessedWords) assessed", color: Color.primary.opacity(0.22))
            }
            .opacity(revealed ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28).padding(.horizontal, 18)
        .sheetSurface(radius: 30)
    }

    private var verdict: String {
        guard let accuracy = stats.accuracy else { return "Nothing scored yet" }
        switch accuracy {
        case 0.95...: return "Nearly word for word"
        case 0.85..<0.95: return "Close to the page"
        case 0.7..<0.85: return "The shape was there"
        default: return "Plenty to revisit"
        }
    }

    private var narrative: String {
        guard stats.assessedWords > 0 else {
            return "No finalized speech was matched to the manuscript in this run."
        }
        var sentence = "Of the \(stats.assessedWords) words you reached, about \(stats.matchedWords) were heard as written"
        if let rate = stats.wordsPerMinute {
            sentence += ", at a \(PaceBand(wordsPerMinute: rate).title.lowercased()) \(Int(rate.rounded())) words a minute"
        }
        return sentence + "."
    }

    private func chip(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(Theme.ink.opacity(0.8))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Theme.paper, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
