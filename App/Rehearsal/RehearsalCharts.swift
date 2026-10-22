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
    static let matched = Theme.accent
    static let missed = Theme.missed
    static let unassessed = Color.primary.opacity(0.07)
}

/// The report's centerpiece: matched words sweep around first, then the misses.
/// `progress` runs 0…1 so the ring can draw itself in when the report opens.
struct MatchRing: View {
    let matched: Int
    let missed: Int
    var progress: Double = 1
    var diameter: CGFloat = 196
    private let lineWidth: CGFloat = 15
    private var assessed: Int { matched + missed }
    private var share: Double { assessed > 0 ? Double(matched) / Double(assessed) : 0 }
    private var percentage: String {
        assessed > 0 ? "\(Int((share * 100).rounded()))%" : "--"
    }

    var body: some View {
        let gap = matched > 0 && missed > 0 ? 0.012 : 0
        ZStack {
            Circle().stroke(RehearsalColor.unassessed, lineWidth: lineWidth)
            if assessed > 0 {
                arc(0, max(0, share - gap) * progress)
                    .stroke(RehearsalColor.matched, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if missed > 0 {
                    let start = min(1, share + gap)
                    arc(start, start + max(0, 1 - start - gap) * progress)
                        .stroke(RehearsalColor.missed, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(assessed > 0 ? "\(Int((share * 100 * progress).rounded()))" : "\u{2014}")
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: share * progress))
                    if assessed > 0 {
                        Text("%").font(.figure(.title3, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(assessed > 0 ? Theme.ink : Color.secondary)
                Text("Est. match").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(lineWidth + 14)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated script match in assessed text")
        .accessibilityValue(assessed > 0 ? "\(percentage), \(matched) matched, \(missed) estimated missed, \(assessed) assessed words" : "Not assessed")
    }

    private func arc(_ from: Double, _ to: Double) -> some Shape {
        Circle().trim(from: from, to: max(from, to)).rotation(.degrees(-90))
    }
}

/// Every word of the manuscript as a tile, from the first line to the last.
/// Tiles fill in as a wave while `progress` runs from 0 to 1.
struct WordCoverageMap: View, Animatable {
    let bins: [CoverageBin]
    var progress: Double = 1
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    private var columns: Int { min(24, max(1, bins.count)) }
    private let gap = 3.0
    private let cellHeight = 10.0
    private var rows: Int { (bins.count + columns - 1) / columns }

    var body: some View {
        Canvas { context, size in
            let width = max(0, (size.width - gap * Double(columns - 1)) / Double(columns))
            let capacity = Double(max(1, bins.map(\.total).max() ?? 1))
            let front = progress * Double(bins.count + 12)
            for (index, bin) in bins.enumerated() {
                let rect = CGRect(x: Double(index % columns) * (width + gap),
                                  y: Double(index / columns) * (cellHeight + gap),
                                  width: width * Double(bin.total) / capacity, height: cellHeight)
                let shape = Path(roundedRect: rect, cornerRadius: 2.5, style: .continuous)
                context.fill(shape, with: .color(RehearsalColor.unassessed))
                let reveal = min(1, max(0, (front - Double(index)) / 12))
                guard reveal > 0 else { continue }
                var colored = context
                colored.opacity = reveal
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
