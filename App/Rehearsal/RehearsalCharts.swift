import Charts
import SwiftUI

struct CoverageBin: Equatable {
    let matched: Int
    let missed: Int
    let total: Int
    var unassessed: Int { total - matched - missed }

    static func make(wordCount: Int, matched: [Int], missed: [Int], maximumBins: Int = 240) -> [CoverageBin] {
        guard wordCount > 0 else { return [] }
        let matchedSet = Set(matched.filter { (0..<wordCount).contains($0) })
        let missedSet = Set(missed.filter { (0..<wordCount).contains($0) }).subtracting(matchedSet)
        // Equal full-tile area represents equal word counts; only the final tile can be partial.
        let wordsPerBin = (wordCount - 1) / max(1, maximumBins) + 1
        return stride(from: 0, to: wordCount, by: wordsPerBin).map { start in
            let end = start + min(wordsPerBin, wordCount - start)
            var matched = 0
            var missed = 0
            for index in start..<end {
                if matchedSet.contains(index) { matched += 1 }
                else if missedSet.contains(index) { missed += 1 }
            }
            return CoverageBin(matched: matched, missed: missed, total: end - start)
        }
    }
}

enum RehearsalColor {
    static let matched = Color.accentColor
    static let missed = Color(red: 0.79, green: 0.27, blue: 0.15)
    static let unassessed = Color(uiColor: .tertiarySystemFill)
}

struct MatchRing: View {
    let matched: Int
    let missed: Int
    private var assessed: Int { matched + missed }
    private var percentage: String {
        assessed > 0 ? "\(Int((Double(matched) / Double(assessed) * 100).rounded()))%" : "--"
    }

    var body: some View {
        ZStack {
            if assessed > 0 {
                Chart {
                    if matched > 0 {
                        SectorMark(angle: .value("Matched", matched), innerRadius: .ratio(0.82), angularInset: 2)
                            .cornerRadius(3).foregroundStyle(RehearsalColor.matched)
                    }
                    if missed > 0 {
                        SectorMark(angle: .value("Estimated missed", missed), innerRadius: .ratio(0.82), angularInset: 2)
                            .cornerRadius(3).foregroundStyle(RehearsalColor.missed)
                    }
                }
                .chartLegend(.hidden)
            } else {
                Circle().strokeBorder(RehearsalColor.unassessed, lineWidth: 14)
            }
            VStack(spacing: 3) {
                Text(percentage)
                    .font(.system(.largeTitle, design: .rounded, weight: .medium))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                Text("Est. match").font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(30)
        }
        .frame(width: 176, height: 176)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated script match in assessed text")
        .accessibilityValue(assessed > 0 ? "\(percentage), \(matched) matched, \(missed) estimated missed, \(assessed) assessed words" : "Not assessed")
    }
}

struct WordCoverageMap: View {
    let bins: [CoverageBin]
    private var columns: Int { min(24, max(1, bins.count)) }
    private let gap = 3.0
    private let cellHeight = 9.0
    private var rows: Int { (bins.count + columns - 1) / columns }

    var body: some View {
        Canvas { context, size in
            let width = max(0, (size.width - gap * Double(columns - 1)) / Double(columns))
            let capacity = Double(max(1, bins.map(\.total).max() ?? 1))
            for (index, bin) in bins.enumerated() {
                let rect = CGRect(x: Double(index % columns) * (width + gap),
                                  y: Double(index / columns) * (cellHeight + gap),
                                  width: width * Double(bin.total) / capacity, height: cellHeight)
                let shape = Path(roundedRect: rect, cornerRadius: 1.5)
                context.fill(shape, with: .color(RehearsalColor.unassessed))
                var colored = context
                colored.clip(to: shape)
                let matchedWidth = width * Double(bin.matched) / capacity
                let missedWidth = width * Double(bin.missed) / capacity
                colored.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: matchedWidth, height: cellHeight)), with: .color(RehearsalColor.matched))
                colored.fill(Path(CGRect(x: rect.minX + matchedWidth, y: rect.minY, width: missedWidth, height: cellHeight)), with: .color(RehearsalColor.missed))
            }
        }
        .frame(height: max(0, Double(rows) * (cellHeight + gap) - gap))
        .accessibilityHidden(true)
    }
}
