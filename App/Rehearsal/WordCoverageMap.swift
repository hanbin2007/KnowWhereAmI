import SwiftUI

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
