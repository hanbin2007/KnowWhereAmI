import SwiftUI

/// Floating Liquid Glass controls in the thumb zone. One glass panel carries the
/// mode picker and read-outs; below it sit individual glass buttons that morph
/// between Rehearsal and Live inside a shared `GlassEffectContainer`. Content
/// keeps scrolling beneath, softened by the system scroll edge effect.
struct ReaderTransport: View {
    let model: ReaderModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Namespace private var glass
    @State private var cueFeedback = 0

    /// Concentric with the iPhone's display corners at a 16 pt inset.
    static let panelRadius: CGFloat = 38

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 12) {
                ConsolePanel(model: model)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Self.panelRadius, style: .continuous))
                    .glassEffectID("panel", in: glass)
                if model.mode == .rehearsal {
                    RehearsalControls(model: model, glass: glass) { cueFeedback += 1 }
                } else {
                    LiveControls(model: model, glass: glass) { cueFeedback += 1 }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 6)
        .background { ScrollEdgeAnchor(edge: .bottom).padding(.top, -24).ignoresSafeArea(edges: .bottom) }
        .calmAnimation(Motion.morph, value: model.mode)
        .calmAnimation(Motion.snappy, value: model.stageLocked)
        .sensoryFeedback(.selection, trigger: cueFeedback)
        .transaction { if reducedMotion { $0.disablesAnimations = true } }
    }
}
