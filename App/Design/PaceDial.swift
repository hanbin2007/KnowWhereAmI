import SwiftUI

/// A watch-style subdial for speaking pace. The open arc spans 60–220 words per
/// minute; the conversational band is drawn as a slightly firmer stretch of track.
struct PaceDial: View {
    let wordsPerMinute: Double?
    var diameter: CGFloat = 66
    private static let range = 60.0...220.0
    private static let sweep = 0.75

    private func fraction(_ value: Double) -> Double {
        let clamped = min(Self.range.upperBound, max(Self.range.lowerBound, value))
        return (clamped - Self.range.lowerBound) / (Self.range.upperBound - Self.range.lowerBound)
    }

    var body: some View {
        let value = wordsPerMinute.map(fraction) ?? 0
        let band = (fraction(PaceBand.comfortable.lowerBound), fraction(PaceBand.comfortable.upperBound))
        ZStack {
            arc(0, Self.sweep).stroke(Theme.track, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            arc(Self.sweep * band.0, Self.sweep * band.1)
                .stroke(Theme.accent.opacity(0.18), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            arc(0, Self.sweep * value)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .opacity(wordsPerMinute == nil ? 0 : 1)
            Circle()
                .fill(Theme.sheet)
                .overlay { Circle().strokeBorder(Theme.accent, lineWidth: 2) }
                .frame(width: 9, height: 9)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(-135 + 270 * value))
                .opacity(wordsPerMinute == nil ? 0 : 1)
            VStack(spacing: -1) {
                Text(wordsPerMinute.map { "\(Int($0.rounded()))" } ?? "\u{2014}")
                    .font(.figure(.title3, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: wordsPerMinute ?? 0))
                    .foregroundStyle(wordsPerMinute == nil ? .tertiary : .primary)
                Text("wpm").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            .padding(10)
        }
        .frame(width: diameter, height: diameter)
    }

    private func arc(_ from: Double, _ to: Double) -> some Shape {
        Circle().trim(from: from, to: max(from, to)).rotation(.degrees(135))
    }
}
