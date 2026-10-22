import SwiftUI

struct ReaderTransport: View {
    let model: ReaderModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Namespace private var motion
    @State private var cueFeedback = 0

    var body: some View {
        VStack(spacing: 14) {
            modeSwitch
            if model.mode == .rehearsal {
                TimelineView(.periodic(from: .now, by: 1)) { _ in rehearsalConsole }
                    .transition(.opacity)
            } else {
                liveConsole.transition(.opacity)
            }
            if case .downloading(let value) = model.phase {
                ProgressView(value: value) {
                    Text("English model").font(.caption)
                } currentValueLabel: {
                    Text(value, format: .percent.precision(.fractionLength(0))).font(.caption.monospacedDigit())
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10)
        .background(Color(uiColor: .systemBackground))
        .fixedSize(horizontal: false, vertical: true)
        .animation(reducedMotion ? nil : ReaderChrome.motion, value: model.mode)
        .sensoryFeedback(.selection, trigger: cueFeedback)
        .transaction { if reducedMotion { $0.disablesAnimations = true } }
    }

    private var modeSwitch: some View {
        HStack(spacing: 28) {
            ForEach(ReaderMode.allCases) { mode in
                Button { model.setMode(mode) } label: {
                    VStack(spacing: 9) {
                        Label(mode.title, systemImage: mode == .rehearsal ? "waveform" : "bolt.horizontal")
                            .font(.subheadline.weight(model.mode == mode ? .semibold : .regular))
                            .foregroundStyle(model.mode == mode ? .primary : .secondary)
                            .lineLimit(1).minimumScaleFactor(0.75)
                        ZStack {
                            Capsule().fill(.clear)
                            if model.mode == mode {
                                Capsule().fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "mode", in: motion)
                            }
                        }
                        .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mode-\(mode.rawValue)")
                .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain).accessibilityLabel("Reading mode")
        .accessibilityIdentifier("readingMode").disabled(isStopping)
    }

    private var rehearsalConsole: some View {
        let stats = model.statistics
        return VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.wordsPerMinute.map { String(Int($0.rounded())) } ?? "--")
                        .font(.system(.title, design: .rounded, weight: .medium))
                        .monospacedDigit().contentTransition(.numericText())
                    Text("Words / min").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Words per minute: \(stats.wordsPerMinute.map { String(Int($0.rounded())) } ?? "Not available")")
                .accessibilityIdentifier("rehearsalMetrics")
                primaryButton
                VStack(alignment: .trailing, spacing: 3) {
                    Text(stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "--")
                        .font(.system(.title, design: .rounded, weight: .medium))
                        .monospacedDigit().contentTransition(.numericText())
                    Text("Est. match").font(.caption2).foregroundStyle(.secondary)
                    Text(stats.assessedWords > 0 ? "\(stats.missedWords) est. missed" : "Not assessed")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Estimated script match: \(stats.accuracy.map { "\(Int(($0 * 100).rounded())) percent, \(stats.missedWords) estimated missed words" } ?? "Not assessed")")
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            .animation(reducedMotion ? nil : .smooth(duration: 0.2), value: stats.spokenWords)
            status
            HStack(spacing: 10) {
                iconButton("Restart from beginning", symbol: "arrow.counterclockwise", id: "restartReading", action: model.restart)
                Text(ReaderChrome.time(stats.elapsedSeconds))
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).contentTransition(.numericText())
                    .accessibilityLabel("Active listening time: \(ReaderChrome.time(stats.elapsedSeconds))")
                iconButton("Finish rehearsal", symbol: "checkmark", id: "finishRehearsal") { model.finishRehearsal() }
                    .disabled(!model.hasRehearsal || isStopping)
                recenterButton
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .modifier(ReaderGlass()).buttonStyle(ReaderControlStyle()).disabled(isStopping)
        }
    }

    private var liveConsole: some View {
        VStack(spacing: 12) {
            status
            HStack(spacing: 4) {
                Toggle(isOn: Binding(get: { model.stageLocked }, set: { model.stageLocked = $0 })) {
                    Image(systemName: model.stageLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 18)).frame(width: 44, height: 48).contentShape(Rectangle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .toggleStyle(.button).buttonStyle(.plain)
                .foregroundStyle(model.stageLocked ? Color.accentColor : .secondary)
                .accessibilityLabel("Lock reading position").accessibilityIdentifier("stageLock")
                .accessibilityValue(model.stageLocked ? "Locked" : "Unlocked").help("Lock reading position")
                Spacer(minLength: 0)
                iconButton("Previous paragraph", symbol: "backward.end.fill", id: "previousParagraph") {
                    model.jumpParagraph(-1); cueFeedback += 1
                }.disabled(!model.canJumpParagraph(-1))
                Spacer(minLength: 0)
                primaryButton
                Spacer(minLength: 0)
                iconButton("Next paragraph", symbol: "forward.end.fill", id: "nextParagraph") {
                    model.jumpParagraph(1); cueFeedback += 1
                }.disabled(!model.canJumpParagraph(1))
                Spacer(minLength: 0)
                recenterButton
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .modifier(ReaderGlass()).buttonStyle(ReaderControlStyle()).disabled(isStopping)
        }
    }

    private var status: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(model.statusTitle).font(.caption.weight(.medium))
                .lineLimit(1).minimumScaleFactor(0.65).layoutPriority(1)
                .contentTransition(.opacity).accessibilityIdentifier("readerStatus")
            Spacer(minLength: 8)
            Text("\(model.position) / \(model.document.words.count)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.65).contentTransition(.numericText())
                .accessibilityLabel("Position \(model.position) of \(model.document.words.count) words")
                .accessibilityIdentifier("readerPosition")
        }
    }

    private var primaryButton: some View {
        Button(action: model.toggleListening) {
            ZStack {
                Circle().strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1.5)
                Circle().trim(from: 0, to: model.progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(0.75).accessibilityHidden(true)
                Circle().fill(ReaderChrome.buttonFill).padding(5)
                if isStopping {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: microphoneSymbol).font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white).contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 78, height: 78).contentShape(Circle())
        }
        .buttonStyle(ReaderControlStyle()).matchedGeometryEffect(id: "microphone", in: motion)
        .accessibilityLabel(primaryActionTitle).accessibilityIdentifier("toggleListening").help(primaryActionTitle)
        .disabled(model.document.words.isEmpty || isStopping)
        .animation(reducedMotion ? nil : .smooth(duration: 0.18), value: model.phase)
    }

    private var recenterButton: some View {
        iconButton("Return to reading position", symbol: "scope", id: "recenterReading") {
            model.recenter(); cueFeedback += 1
        }.foregroundStyle(model.followsPosition ? Color.secondary : .accentColor)
    }

    private func iconButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                .frame(width: 44, height: 48).contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(title).accessibilityIdentifier(id).help(title).disabled(model.document.words.isEmpty)
    }

    private var isStopping: Bool { model.phase == .stopping || model.phase == .finishing }
    private var microphoneSymbol: String {
        switch model.phase {
        case .listening: "pause.fill"
        case .preparing, .downloading: "xmark"
        default: "mic.fill"
        }
    }
    private var primaryActionTitle: String {
        switch model.phase {
        case .listening: "Pause listening"
        case .preparing, .downloading: "Cancel preparation"
        case .stopping, .finishing: "Stopping microphone"
        case .paused: "Resume listening"
        case .finished: "Read again"
        default: "Start listening"
        }
    }
    private var statusColor: Color {
        switch model.phase {
        case .listening: model.isFindingPosition ? .orange : .accentColor
        case .preparing, .downloading, .finishing: .orange
        case .finished: .accentColor
        default: .secondary
        }
    }
}
