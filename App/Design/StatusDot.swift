import SwiftUI

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
            .onAppear { restart() }
            .onChange(of: pulsing) { restart() }
            .accessibilityHidden(true)
    }

    private func restart() {
        expanded = false
        guard pulsing, !reducedMotion else { return }
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { expanded = true }
    }
}
