import SwiftUI

/// A circular, interactive Liquid Glass button for secondary console actions.
struct GlassIconButton: View {
    static let size: CGFloat = 52
    let title: String
    let symbol: String
    let id: String
    let glass: Namespace.ID
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: Self.size, height: Self.size)
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(GlassControlStyle())
        .glassEffect(.regular.interactive(), in: Circle())
        .glassEffectID(id, in: glass)
        .accessibilityLabel(title).accessibilityIdentifier(id).help(title)
    }
}

/// Interactive glass already answers touches with its own scale and shimmer,
/// so the label only needs to show the disabled state.
struct GlassControlStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(enabled ? 1 : 0.35)
    }
}
