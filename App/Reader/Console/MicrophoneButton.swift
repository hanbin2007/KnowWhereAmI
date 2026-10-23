import SwiftUI

/// The primary action and the only tinted glass in the console. A progress
/// ring around it shows how far through the manuscript the reader is.
struct MicrophoneButton: View {
    static let size: CGFloat = 74
    let model: ReaderModel
    let glass: Namespace.ID

    var body: some View {
        Button { model.toggleListening() } label: {
            ZStack {
                if model.isStopping {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: model.microphoneSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: Self.size, height: Self.size)
            .contentShape(Circle())
        }
        .buttonStyle(GlassControlStyle())
        .glassEffect(.regular.tint(Theme.accentDeep).interactive(), in: Circle())
        .glassEffectID("microphone", in: glass)
        .background {
            ZStack {
                ListeningHalo(active: model.phase == .listening)
                Circle().stroke(Theme.track, lineWidth: 2.5)
                Circle().trim(from: 0, to: model.progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .calmAnimation(Motion.gentle, value: model.progress)
            }
            .frame(width: Self.size + 12, height: Self.size + 12)
            .accessibilityHidden(true)
        }
        .padding(6)
        .accessibilityLabel(model.primaryActionTitle).accessibilityIdentifier("toggleListening")
        .help(model.primaryActionTitle)
        .disabled(model.document.words.isEmpty || model.isStopping)
        .calmAnimation(Motion.snappy, value: model.phase)
    }
}
