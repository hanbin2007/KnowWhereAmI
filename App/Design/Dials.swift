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

/// A compact two-tone ring: matched words, then estimated misses.
struct MatchDial: View {
    let matched: Int
    let missed: Int
    var diameter: CGFloat = 66
    var lineWidth: CGFloat = 4
    var showsValue = true
    private var assessed: Int { matched + missed }
    private var share: Double { assessed > 0 ? Double(matched) / Double(assessed) : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            if assessed > 0 {
                ring(from: 0, to: share).stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if missed > 0 {
                    ring(from: min(1, share + gap), to: 1 - gap)
                        .stroke(Theme.missed, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
            if showsValue {
                VStack(spacing: -1) {
                    Text(assessed > 0 ? "\(Int((share * 100).rounded()))" : "\u{2014}")
                        .font(.figure(.title3, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: share))
                        .foregroundStyle(assessed > 0 ? .primary : .tertiary)
                    Text("% match").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(10)
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

/// Soft rings that breathe outward while the microphone is open.
struct ListeningHalo: View {
    let active: Bool
    var color: Color = Theme.accent
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        if active, !reducedMotion {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<2, id: \.self) { ring in
                        let phase = (time / 2.6 + Double(ring) / 2).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .stroke(color.opacity(0.32 * (1 - phase)), lineWidth: 1.5)
                            .scaleEffect(1 + 0.36 * phase)
                    }
                }
            }
            .transition(.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else if active {
            Circle().stroke(color.opacity(0.25), lineWidth: 1.5).scaleEffect(1.12)
                .accessibilityHidden(true)
        }
    }
}

/// A status dot that pulses gently while something is in progress.
struct StatusDot: View {
    let color: Color
    let pulsing: Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var expanded = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .background {
                Circle().fill(color.opacity(0.35))
                    .scaleEffect(expanded ? 2.4 : 1)
                    .opacity(expanded ? 0 : 1)
                    .opacity(pulsing && !reducedMotion ? 1 : 0)
            }
            .onAppear(perform: restart)
            .onChange(of: pulsing) { restart() }
            .accessibilityHidden(true)
    }

    private func restart() {
        expanded = false
        guard pulsing, !reducedMotion else { return }
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { expanded = true }
    }
}
