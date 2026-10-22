import KnowWhereAmICore
import SwiftUI

/// The floating console in the thumb zone. Rehearsal surrounds the microphone
/// with pace and match dials; Live folds it into a compact rescue dock.
struct ReaderTransport: View {
    let model: ReaderModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var dialSize = 66.0
    @Namespace private var motion
    @State private var cueFeedback = 0

    var body: some View {
        VStack(spacing: 12) {
            modeSwitch
            console
        }
        .padding(.horizontal, 16).padding(.bottom, 4)
        .background(alignment: .bottom) { scrim }
        .fixedSize(horizontal: false, vertical: true)
        .calmAnimation(Motion.morph, value: model.mode)
        .sensoryFeedback(.selection, trigger: cueFeedback)
        .transaction { if reducedMotion { $0.disablesAnimations = true } }
    }

    /// Lets the manuscript dissolve into the paper just above the mode switch,
    /// so neither the switch nor the glass console ever shows text behind it.
    private var scrim: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.paper.opacity(0), Theme.paper.opacity(0.9), Theme.paper],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 56)
            Theme.paper
        }
        .padding(.top, -48)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Mode

    private var modeSwitch: some View {
        HStack(spacing: 2) {
            ForEach(ReaderMode.allCases) { mode in
                let selected = model.mode == mode
                Button { model.setMode(mode) } label: {
                    Label(mode.title, systemImage: mode == .rehearsal ? "waveform" : "dot.radiowaves.left.and.right")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(selected ? Theme.ink : .secondary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background {
                            if selected {
                                Capsule().fill(Theme.sheet)
                                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "modeThumb", in: motion)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mode-\(mode.rawValue)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.track, in: Capsule())
        .accessibilityElement(children: .contain).accessibilityLabel("Reading mode")
        .accessibilityIdentifier("readingMode").disabled(isStopping)
    }

    // MARK: Console

    private var console: some View {
        VStack(spacing: model.mode == .rehearsal ? 16 : 14) {
            statusRow
            if case .downloading(let value) = model.phase {
                ProgressView(value: value)
                    .tint(Theme.amber)
                    .accessibilityLabel("English speech model")
                    .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
                    .transition(.opacity)
            }
            if model.mode == .rehearsal {
                rehearsalBody.transition(.blurReplace)
            } else {
                liveBody.transition(.blurReplace)
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)
        .readerGlass(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .disabled(isStopping)
    }

    private var statusRow: some View {
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
                StatusDot(color: statusColor, pulsing: isWorking)
            }
            Text(model.statusTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(1).minimumScaleFactor(0.65).layoutPriority(1)
                .contentTransition(.interpolate)
                .accessibilityIdentifier("readerStatus")
            Spacer(minLength: 8)
            Text("\(Text("\(model.position)").foregroundStyle(Theme.ink)) / \(model.document.words.count)")
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

    // MARK: Rehearsal

    private var rehearsalBody: some View {
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: 1, paused: model.phase != .listening)) { _ in
                let stats = model.statistics
                HStack(alignment: .top, spacing: 0) {
                    dialColumn(caption: stats.wordsPerMinute.map { PaceBand(wordsPerMinute: $0).title } ?? "Pace") {
                        PaceDial(wordsPerMinute: stats.wordsPerMinute, diameter: dial)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Words per minute: \(stats.wordsPerMinute.map { String(Int($0.rounded())) } ?? "Not available")")
                    .accessibilityIdentifier("rehearsalMetrics")
                    microphone
                    dialColumn(caption: matchCaption(stats)) {
                        MatchDial(matched: stats.matchedWords, missed: stats.missedWords, diameter: dial)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Estimated script match: \(stats.accuracy.map { "\(Int(($0 * 100).rounded())) percent, \(stats.missedWords) estimated missed words" } ?? "Not assessed")")
                }
                .calmAnimation(Motion.gentle, value: stats.spokenWords)
            }
            Rectangle().fill(Theme.hairline).frame(height: 0.75).accessibilityHidden(true)
            HStack(spacing: 4) {
                iconButton("Restart from beginning", symbol: "arrow.counterclockwise", id: "restartReading") { model.restart() }
                TimelineView(.animation(minimumInterval: 1, paused: model.phase != .listening)) { _ in
                    let elapsed = ReaderChrome.time(model.elapsedSeconds)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(elapsed).font(.figure(.headline)).monospacedDigit()
                            .contentTransition(.numericText())
                        Text("Active time").font(.caption2).foregroundStyle(.secondary)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Active listening time: \(elapsed)")
                }
                .padding(.leading, 2)
                Spacer(minLength: 8)
                finishButton
                recenterButton
            }
            .buttonStyle(ReaderControlStyle())
        }
    }

    private var dial: CGFloat { min(dialSize, 92) }

    private func dialColumn<Dial: View>(caption: String, @ViewBuilder dial: () -> Dial) -> some View {
        VStack(spacing: 8) {
            dial()
            Text(caption).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.interpolate)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func matchCaption(_ stats: RehearsalStatistics) -> String {
        guard stats.assessedWords > 0 else { return "Match" }
        return stats.missedWords == 0 ? "Nothing missed" : "\(stats.missedWords) est. missed"
    }

    private var finishButton: some View {
        Button { model.finishRehearsal() } label: {
            ViewThatFits(in: .horizontal) {
                Label("Finish", systemImage: "checkmark").padding(.horizontal, 16)
                Image(systemName: "checkmark").frame(width: 46)
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 46)
            .background(Theme.accent.opacity(model.hasRehearsal ? 0.14 : 0.06), in: Capsule())
            .contentShape(Capsule())
        }
        .foregroundStyle(Theme.accent)
        .accessibilityLabel("Finish rehearsal").accessibilityIdentifier("finishRehearsal").help("Finish rehearsal")
        .disabled(!model.hasRehearsal || isStopping)
    }

    // MARK: Live

    private var liveBody: some View {
        VStack(spacing: 14) {
            ParagraphRail(starts: model.paragraphStarts, wordCount: model.document.words.count, cursor: model.cursor)
            HStack(spacing: 0) {
                Toggle(isOn: Binding(get: { model.stageLocked }, set: { model.stageLocked = $0 })) {
                    Image(systemName: model.stageLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .background(model.stageLocked ? Theme.accent.opacity(0.16) : Theme.track, in: Circle())
                        .contentShape(Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .toggleStyle(.button).buttonStyle(.plain)
                .foregroundStyle(model.stageLocked ? Theme.accent : .secondary)
                .accessibilityLabel("Lock reading position").accessibilityIdentifier("stageLock")
                .accessibilityValue(model.stageLocked ? "Locked" : "Unlocked").help("Lock reading position")
                Spacer(minLength: 0)
                iconButton("Previous paragraph", symbol: "backward.end.fill", id: "previousParagraph", filled: true) {
                    model.jumpParagraph(-1); cueFeedback += 1
                }.disabled(!model.canJumpParagraph(-1))
                Spacer(minLength: 0)
                microphone
                Spacer(minLength: 0)
                iconButton("Next paragraph", symbol: "forward.end.fill", id: "nextParagraph", filled: true) {
                    model.jumpParagraph(1); cueFeedback += 1
                }.disabled(!model.canJumpParagraph(1))
                Spacer(minLength: 0)
                recenterButton
            }
            .buttonStyle(ReaderControlStyle())
        }
    }

    // MARK: Controls

    private var microphone: some View {
        Button { model.toggleListening() } label: {
            ZStack {
                ListeningHalo(active: model.phase == .listening)
                Circle().stroke(Theme.track, lineWidth: 2.5)
                Circle().trim(from: 0, to: model.progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .calmAnimation(Motion.gentle, value: model.progress)
                PreparingArc(active: isPreparing)
                Circle().fill(Theme.microphone).padding(7)
                    .shadow(color: ReaderChrome.buttonFill.opacity(0.35), radius: 10, y: 5)
                Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1).padding(7).blendMode(.plusLighter)
                if isStopping {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: microphoneSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 84, height: 84)
            .contentShape(Circle())
        }
        .buttonStyle(ReaderControlStyle(pressedScale: 0.92))
        .matchedGeometryEffect(id: "microphone", in: motion)
        .accessibilityLabel(primaryActionTitle).accessibilityIdentifier("toggleListening").help(primaryActionTitle)
        .disabled(model.document.words.isEmpty || isStopping)
        .calmAnimation(Motion.snappy, value: model.phase)
    }

    private var recenterButton: some View {
        iconButton("Return to reading position", symbol: "scope", id: "recenterReading", filled: model.mode == .live,
                   tint: model.followsPosition ? Color.secondary : Theme.accent) {
            model.recenter(); cueFeedback += 1
        }
    }

    private func iconButton(_ title: String, symbol: String, id: String, filled: Bool = false,
                            tint: Color = Theme.ink, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(filled ? Theme.track : .clear, in: Circle())
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .foregroundStyle(tint)
        .accessibilityLabel(title).accessibilityIdentifier(id).help(title).disabled(model.document.words.isEmpty)
    }

    // MARK: State

    private var isStopping: Bool { model.phase == .stopping || model.phase == .finishing }
    private var isPreparing: Bool {
        switch model.phase {
        case .preparing, .downloading: true
        default: false
        }
    }
    private var isWorking: Bool { model.phase == .listening || isPreparing || model.phase == .finishing }
    private var microphoneSymbol: String {
        switch model.phase {
        case .listening: "pause.fill"
        case .preparing, .downloading: "xmark"
        case .finished: "arrow.counterclockwise"
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
        case .listening: model.isFindingPosition ? Theme.amber : Theme.accent
        case .preparing, .downloading, .finishing: Theme.amber
        case .finished: Theme.accent
        default: Color.secondary.opacity(0.6)
        }
    }
}

/// An amber comet that circles the microphone while speech is being prepared.
private struct PreparingArc: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        if active {
            TimelineView(.animation(paused: reducedMotion)) { context in
                Circle().trim(from: 0, to: 0.24)
                    .stroke(AngularGradient(colors: [Theme.amber.opacity(0), Theme.amber], center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(86)),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate * 300))
            }
            .transition(.opacity)
            .accessibilityHidden(true)
        }
    }
}

/// Paragraphs as proportional segments: spoken, current, and still ahead.
struct ParagraphRail: View {
    let starts: [Int]
    let wordCount: Int
    let cursor: Int?

    var body: some View {
        let current = starts.lastIndex(where: { $0 <= (cursor ?? 0) }) ?? 0
        GeometryReader { geometry in
            let gap = 3.0
            let usable = max(0, geometry.size.width - gap * Double(max(0, starts.count - 1)))
            HStack(spacing: gap) {
                ForEach(starts.indices, id: \.self) { index in
                    let end = index + 1 < starts.count ? starts[index + 1] : wordCount
                    let share = wordCount > 0 ? Double(end - starts[index]) / Double(wordCount) : 0
                    Capsule()
                        .fill(index < current ? Theme.accent.opacity(0.45) : index == current ? Theme.accent : Theme.track)
                        .frame(width: max(3, usable * share))
                }
            }
        }
        .frame(height: 4)
        .calmAnimation(Motion.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paragraph \(starts.isEmpty ? 0 : current + 1) of \(starts.count)")
        .accessibilityIdentifier("paragraphRail")
    }
}
