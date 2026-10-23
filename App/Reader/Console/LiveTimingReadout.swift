import KnowWhereAmICore
import SwiftUI

struct LiveTimingReadout: View {
    let model: ReaderModel
    var compact = false
    @State private var showsSettings = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let value = model.liveTimer
            VStack(spacing: 6) {
                if !compact {
                    HStack(spacing: 10) {
                        Text(value.hasStarted ? "Time left" : "Time limit")
                            .font(.caption.weight(.medium)).foregroundStyle(Theme.instrumentSecondary)
                        Spacer(minLength: 4)
                        ParagraphRail(starts: model.paragraphStarts, wordCount: model.document.words.count, cursor: model.cursor)
                            .frame(width: 76)
                        if !typeSize.isAccessibilitySize { settingsButton }
                    }
                }
                if typeSize.isAccessibilitySize {
                    HStack {
                        clock(value)
                        settingsButton
                    }
                    forecast(value)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        clock(value)
                        forecast(value).frame(maxWidth: .infinity, alignment: .leading)
                        if compact { settingsButton }
                    }
                }
                if !compact {
                    ProgressView(value: value.remainingFraction)
                        .tint(color(value))
                        .accessibilityLabel("Time budget remaining")
                        .accessibilityValue("\(Int(value.remainingFraction * 100)) percent")
                }
            }
            .calmAnimation(Motion.snappy, value: value.state)
        }
        .sheet(isPresented: $showsSettings) {
            LiveTimerSettings(model: model)
                .presentationDragIndicator(.visible)
        }
    }

    private func clock(_ value: LiveTimingSnapshot) -> some View {
        Text(value.clockText)
            .font(.system(size: compact ? 36 : 50, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color(value))
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, minHeight: compact ? 46 : 64, alignment: .leading)
            .contentTransition(.numericText(countsDown: value.remainingSeconds >= 0))
            .calmAnimation(.linear(duration: 0.2), value: value.clockText)
            .accessibilityLabel(!value.hasStarted ? "Time limit" : value.remainingSeconds < 0 ? "Overtime" : "Time remaining")
            .accessibilityValue(accessibleTime(value.remainingSeconds))
            .accessibilityIdentifier("liveCountdown")
    }

    private var settingsButton: some View {
        Button("Live time limit", systemImage: "timer") { showsSettings = true }
            .labelStyle(.iconOnly)
            .font(.body.weight(.medium))
            .frame(width: 44, height: 44)
            .buttonStyle(.plain)
            .disabled(model.library.selectedID == nil)
            .foregroundStyle(Theme.accent)
            .accessibilityIdentifier("liveTimeSettings")
            .help("Live time limit")
    }

    private func forecast(_ value: LiveTimingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title(value.state), systemImage: symbol(value.state))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor(value))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("liveForecastStatus")
            if !compact || value.estimatedSeconds != nil {
                Text(value.estimatedSeconds.map { "Est. \(LiveTimingSnapshot.formatDuration($0)) to finish" } ?? "Finish estimate pending")
                    .font(.caption).foregroundStyle(Theme.instrumentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("liveEstimatedFinish")
            }
            if !compact {
                Text(detail(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.instrumentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("liveTimingMargin")
            }
        }
    }

    private func statusColor(_ value: LiveTimingSnapshot) -> Color {
        if value.hasStarted && value.remainingSeconds <= 0 { return Theme.overtimeText }
        if value.state == .behind || value.state == .tight { return Theme.warningText }
        return value.state == .onTrack || value.state == .complete ? Theme.accent : Theme.ink
    }

    private func detail(_ value: LiveTimingSnapshot) -> String {
        guard let pace = value.wordsPerMinute else {
            if value.hasStarted, let required = value.requiredWordsPerMinute {
                let number = required > 999 ? "999+" : "\(Int(required.rounded(.up)))"
                return "Need \(number) wpm"
            }
            return "Awaiting speech"
        }
        let rate = "\(Int(pace.rounded())) wpm"
        guard let margin = value.headroomSeconds else { return rate }
        return "\(rate)  |  \(LiveTimingSnapshot.formatDuration(abs(margin))) \(margin < 0 ? "short" : "spare")"
    }

    private func color(_ value: LiveTimingSnapshot) -> Color {
        if value.remainingSeconds <= 0, value.hasStarted { return Theme.onAir }
        if value.state == .behind || value.state == .tight || (value.hasStarted && value.remainingSeconds <= 30) {
            return Theme.amber
        }
        return value.state == .onTrack || value.state == .complete ? Theme.accent : Theme.ink
    }

    private func title(_ state: LiveTimingState) -> String {
        switch state {
        case .ready: "Ready"
        case .estimating: model.phase == .listening ? "Estimating" : "Awaiting speech"
        case .onTrack: "On track"
        case .tight: "Tight finish"
        case .behind: "Behind pace"
        case .overtime: "Overtime"
        case .complete: "Script complete"
        case .locating: model.phase == .listening ? "Finding position" : "Position uncertain"
        case .noScript: "No script"
        }
    }

    private func symbol(_ state: LiveTimingState) -> String {
        switch state {
        case .onTrack, .complete: "checkmark.circle.fill"
        case .tight, .behind: "exclamationmark.triangle.fill"
        case .overtime: "alarm.fill"
        case .locating: "scope"
        default: "timer"
        }
    }

    private func accessibleTime(_ seconds: Double) -> String {
        guard seconds.isFinite, abs(seconds) < Double(Int.max / 2) else { return "Unavailable" }
        let whole = Int(ceil(abs(seconds)))
        return "\(whole / 60) minutes, \(whole % 60) seconds"
    }
}
