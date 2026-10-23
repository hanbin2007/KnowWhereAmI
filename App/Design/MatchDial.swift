import SwiftUI

/// A compact two-tone ring: matched words, then estimated misses.
struct MatchDial: View {
    let matched: Int
    let missed: Int
    var diameter: CGFloat = 66
    var lineWidth: CGFloat = 4
    var showsValue = true
    /// Draws the arcs in from 0 to 1, as Activity rings do.
    var progress: Double = 1
    private var assessed: Int { matched + missed }
    private var share: Double { assessed > 0 ? Double(matched) / Double(assessed) : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            if assessed > 0 {
                ring(from: 0, to: share * progress).stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if missed > 0 {
                    let start = min(1, share + gap)
                    ring(from: start, to: start + max(0, 1 - gap - start) * progress)
                        .stroke(Theme.missed, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
            if showsValue {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(assessed > 0 ? "\(Int((share * 100).rounded()))" : "\u{2014}")
                        .font(.figure(.title3, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: share))
                        .foregroundStyle(assessed > 0 ? .primary : .tertiary)
                    if assessed > 0 {
                        Text("%").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(lineWidth + 6)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// Keeps the two arcs visibly separate once both exist.
    private var gap: Double { missed > 0 && matched > 0 ? min(0.02, Double(lineWidth) / Double(diameter) / 2.5) : 0 }

    private func ring(from: Double, to: Double) -> some Shape {
        Circle().trim(from: max(0, from), to: max(from, to)).rotation(.degrees(-90))
    }
}
