import SwiftUI

/// Rehearsal: restart and recenter on the left, the microphone centred, Finish on the right.
struct RehearsalControls: View {
    let model: ReaderModel
    let glass: Namespace.ID
    let onCue: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                GlassIconButton(title: "Restart from beginning", symbol: "arrow.counterclockwise", id: "restartReading",
                                glass: glass) { model.restart() }
                RecenterButton(model: model, glass: glass, onCue: onCue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MicrophoneButton(model: model, glass: glass)
            FinishButton(model: model, glass: glass)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .disabled(model.document.words.isEmpty || model.isStopping)
    }
}

/// Live: lock and paragraph rescue around the microphone.
struct LiveControls: View {
    let model: ReaderModel
    let glass: Namespace.ID
    let onCue: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Toggle(isOn: Binding(get: { model.stageLocked }, set: { model.stageLocked = $0 })) {
                Image(systemName: model.stageLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(model.stageLocked ? Theme.accent : Color.primary)
                    .frame(width: GlassIconButton.size, height: GlassIconButton.size)
                    .contentShape(Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .toggleStyle(.button)
            .buttonStyle(GlassControlStyle())
            .glassEffect(model.stageLocked ? .regular.tint(Theme.accent.opacity(0.25)).interactive() : .regular.interactive(),
                         in: Circle())
            .glassEffectID("stageLock", in: glass)
            .accessibilityLabel("Lock reading position").accessibilityIdentifier("stageLock")
            .accessibilityValue(model.stageLocked ? "Locked" : "Unlocked").help("Lock reading position")
            Spacer(minLength: 0)
            GlassIconButton(title: "Previous paragraph", symbol: "backward.end.fill", id: "previousParagraph", glass: glass) {
                model.jumpParagraph(-1); onCue()
            }
            .disabled(!model.canJumpParagraph(-1))
            Spacer(minLength: 0)
            MicrophoneButton(model: model, glass: glass)
            Spacer(minLength: 0)
            GlassIconButton(title: "Next paragraph", symbol: "forward.end.fill", id: "nextParagraph", glass: glass) {
                model.jumpParagraph(1); onCue()
            }
            .disabled(!model.canJumpParagraph(1))
            Spacer(minLength: 0)
            RecenterButton(model: model, glass: glass, onCue: onCue)
        }
        .disabled(model.document.words.isEmpty || model.isStopping)
    }
}

struct RecenterButton: View {
    let model: ReaderModel
    let glass: Namespace.ID
    let onCue: () -> Void

    var body: some View {
        GlassIconButton(title: "Return to reading position", symbol: "scope", id: "recenterReading", glass: glass,
                        tint: model.followsPosition ? Color.primary : Theme.accent) {
            model.recenter(); onCue()
        }
    }
}

struct FinishButton: View {
    let model: ReaderModel
    let glass: Namespace.ID

    var body: some View {
        Button { model.finishRehearsal() } label: {
            ViewThatFits(in: .horizontal) {
                Label("Finish", systemImage: "checkmark").padding(.horizontal, 18)
                Image(systemName: "checkmark").frame(width: GlassIconButton.size)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .frame(minHeight: GlassIconButton.size)
            .contentShape(Capsule())
        }
        .buttonStyle(GlassControlStyle())
        .glassEffect(.regular.interactive(), in: Capsule())
        .glassEffectID("finishRehearsal", in: glass)
        .accessibilityLabel("Finish rehearsal").accessibilityIdentifier("finishRehearsal").help("Finish rehearsal")
        .disabled(!model.hasRehearsal)
    }
}
