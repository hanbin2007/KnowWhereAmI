import SwiftUI

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
