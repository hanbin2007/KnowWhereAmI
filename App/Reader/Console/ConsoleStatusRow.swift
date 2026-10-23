import SwiftUI

/// Listening state, active time, and position in the manuscript.
struct ConsoleStatusRow: View {
    let model: ReaderModel

    var body: some View {
        HStack(spacing: 8) {
            if model.mode == .live, model.phase == .listening {
                Text("On air")
                    .font(.caption2.weight(.bold)).tracking(1).textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.onAir, in: Capsule())
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityHidden(true)
            } else {
                StatusDot(color: model.statusColor, pulsing: model.isWorking)
            }
            Text(model.statusTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.65).layoutPriority(1)
                .contentTransition(.interpolate)
                .accessibilityIdentifier("readerStatus")
            if model.mode == .rehearsal {
                TimelineView(.animation(minimumInterval: 1, paused: model.phase != .listening)) { _ in
                    let elapsed = ReaderChrome.time(model.elapsedSeconds)
                    Text(elapsed)
                        .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .accessibilityLabel("Active listening time: \(elapsed)")
                }
                .transition(.opacity)
            }
            Spacer(minLength: 8)
            Text("\(Text("\(model.position)").foregroundStyle(.primary)) / \(model.document.words.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.65)
                .contentTransition(.numericText(value: Double(model.position)))
                .accessibilityLabel("Position \(model.position) of \(model.document.words.count) words")
                .accessibilityIdentifier("readerPosition")
        }
        .calmAnimation(Motion.snappy, value: model.phase)
        .calmAnimation(Motion.snappy, value: model.position)
    }
}
