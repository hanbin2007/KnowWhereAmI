import SwiftUI

/// Listening state on the left; active time and position on the right.
struct ConsoleStatusRow: View {
    let model: ReaderModel
    @ScaledMetric(relativeTo: .subheadline) private var dividerHeight = 12.0

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 7) {
                if model.mode == .live, model.phase == .listening {
                    Text("On air")
                        .font(.caption2.weight(.bold)).tracking(0.8).textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.onAir, in: Capsule())
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .accessibilityHidden(true)
                } else {
                    StatusDot(color: model.statusColor, pulsing: model.isWorking)
                }
                Text(model.statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .contentTransition(.interpolate)
                    .accessibilityIdentifier("readerStatus")
            }
            .layoutPriority(1)
            Spacer(minLength: 12)
            HStack(alignment: .center, spacing: 10) {
                if model.mode == .rehearsal {
                    TimelineView(.animation(minimumInterval: 1, paused: model.phase != .listening)) { _ in
                        let elapsed = ReaderChrome.time(model.elapsedSeconds)
                        Text(elapsed)
                            .contentTransition(.numericText())
                            .accessibilityLabel("Active listening time: \(elapsed)")
                    }
                    Capsule().fill(Theme.hairline).frame(width: 1, height: dividerHeight).accessibilityHidden(true)
                }
                Text("\(Text("\(model.position)").foregroundStyle(.primary)) / \(model.document.words.count)")
                    .contentTransition(.numericText(value: Double(model.position)))
                    .accessibilityLabel("Position \(model.position) of \(model.document.words.count) words")
                    .accessibilityIdentifier("readerPosition")
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1).minimumScaleFactor(0.65)
        }
        .calmAnimation(Motion.snappy, value: model.phase)
        .calmAnimation(Motion.snappy, value: model.position)
    }
}
