import SwiftUI

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
