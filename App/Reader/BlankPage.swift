import SwiftUI

/// Shown when the selected manuscript has no words yet.
struct BlankPage: View {
    let onAdd: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var settled = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                page.rotationEffect(.degrees(settled ? -9 : -3)).offset(x: settled ? -18 : -6, y: 6).opacity(0.55)
                page.rotationEffect(.degrees(settled ? 7 : 2)).offset(x: settled ? 16 : 5, y: 2).opacity(0.8)
                page.overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach([0.82, 0.64, 0.74, 0.4], id: \.self) { width in
                            Capsule().fill(Theme.track).frame(width: 64 * width, height: 4)
                        }
                    }
                    .padding(14)
                }
            }
            .frame(height: 124)
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("A blank page").font(.display(.title2, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("Write, paste, or import the words you plan to say. They stay on this iPhone.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Button("Add script", systemImage: "plus", action: onAdd)
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .accessibilityIdentifier("addScript")
        }
        .padding(.horizontal, 40)
        .onAppear {
            if reducedMotion { settled = true } else { withAnimation(Motion.morph.delay(0.1)) { settled = true } }
        }
    }

    private var page: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.sheet)
            .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75) }
            .frame(width: 92, height: 118)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }
}
