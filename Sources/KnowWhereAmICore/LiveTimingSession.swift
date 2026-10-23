import Foundation

public enum LiveTimingState: Equatable, Sendable {
    case ready, estimating, onTrack, tight, behind, overtime, complete, locating, noScript
}

public struct LiveTimingSnapshot: Sendable {
    public let hasStarted: Bool
    public let limitSeconds: Int
    public let remainingSeconds: Double
    public let wordsPerMinute: Double?
    public let estimatedSeconds: Double?
    public let headroomSeconds: Double?
    public let requiredWordsPerMinute: Double?
    public let state: LiveTimingState

    public var clockText: String {
        (remainingSeconds < 0 ? "+" : "") + Self.formatDuration(abs(remainingSeconds))
    }

    public var remainingFraction: Double { min(1, max(0, remainingSeconds / Double(limitSeconds))) }

    public static func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max / 2) else { return "--:--" }
        let whole = Int(ceil(seconds))
        if whole >= 3_600 {
            return String(format: "%d:%02d:%02d", whole / 3_600, whole / 60 % 60, whole % 60)
        }
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

public struct LiveTimingSession: Sendable {
    public static let allowedLimits = 30...3_600
    private var limitSeconds: Int
    private var startedAt: Double?
    private var paceOrigin: Double?
    private var speechOrigin: Double?
    private var audioOffset: Double?
    private var session = 0
    private var finalizedThrough: Double = 0
    private var samples: [PaceSample] = []
    private static let paceWindow: Double = 30

    public init(limitSeconds: Int = 180) {
        self.limitSeconds = min(Self.allowedLimits.upperBound, max(Self.allowedLimits.lowerBound, limitSeconds))
    }

    public mutating func start(at time: Double) {
        guard time.isFinite, startedAt == nil else { return }
        startedAt = time
        if paceOrigin == nil { paceOrigin = time }
    }

    public mutating func restart(at time: Double) {
        guard time.isFinite else { return }
        startedAt = time
        if paceOrigin == nil { paceOrigin = time }
    }

    public mutating func beginSpeech(at time: Double) {
        guard time.isFinite, speechOrigin == nil else { return }
        start(at: time)
        session += 1
        speechOrigin = time
        audioOffset = time
        finalizedThrough = 0
    }

    public mutating func endSpeech() { speechOrigin = nil }

    public mutating func alignAudio(startingAt audioTime: Double, at time: Double) {
        guard speechOrigin != nil, audioTime.isFinite, time.isFinite else { return }
        let offset = time - audioTime
        guard offset.isFinite else { return }
        if let previous = audioOffset {
            samples = samples.map { $0.session == session ? $0.shifted(by: offset - previous) : $0 }
        }
        audioOffset = offset
    }

    public mutating func setLimit(_ seconds: Int) {
        limitSeconds = min(Self.allowedLimits.upperBound, max(Self.allowedLimits.lowerBound, seconds))
    }

    public mutating func record(_ chunk: SpeechChunk, at time: Double) {
        guard speechOrigin != nil, time.isFinite, chunk.start.isFinite, chunk.end.isFinite,
              chunk.start >= 0, chunk.end > chunk.start,
              chunk.start >= finalizedThrough - 0.001 else { return }
        // Calibrate at audio capture, never at ASR delivery: a delayed final
        // must not move old speech into the current pace window.
        guard let offset = audioOffset else { return }
        let lower = offset + chunk.start
        let upper = offset + chunk.end
        guard lower.isFinite, upper.isFinite else { return }
        if chunk.isFinal { finalizedThrough = max(finalizedThrough, chunk.end) }

        // A prefix final replaces only its own audio, not a later volatile tail.
        samples = samples.flatMap { sample -> [PaceSample] in
            guard sample.session == session, sample.start < upper, sample.end > lower else { return [sample] }
            return [sample.clipped(from: sample.start, to: min(sample.end, lower)),
                    sample.clipped(from: max(sample.start, upper), to: sample.end)].compactMap { $0 }
        }
        let count = ScriptDocument.wordCount(in: chunk.text)
        let timings = chunk.wordTimings.filter {
            $0.start.isFinite && $0.end.isFinite && $0.start >= chunk.start - 0.001
                && $0.end <= chunk.end + 0.001 && $0.end > $0.start
                && $0.wordCount > 0 && $0.wordCount <= count
        }
        if count > 0, timings.reduce(0.0, { $0 + Double($1.wordCount) }) == Double(count) {
            samples += timings.map {
                PaceSample(session: session, start: offset + $0.start,
                           end: offset + $0.end, words: Double($0.wordCount))
            }
        } else if count > 0 {
            samples.append(PaceSample(session: session, start: lower, end: upper, words: Double(count)))
        }
        samples.removeAll { $0.end <= time - Self.paceWindow }
        samples.sort { $0.end < $1.end }
        if samples.count > 512 { samples.removeFirst(samples.count - 512) }
    }

    public func snapshot(at time: Double, remainingWords: Int?, positionReliable: Bool = true) -> LiveTimingSnapshot {
        let now = time.isFinite ? time : (startedAt ?? 0)
        let elapsed = startedAt.map { max(0, now - $0) } ?? 0
        let remaining = Double(limitSeconds) - elapsed
        let words = remainingWords.map { max(0, $0) }
        let pace = recentPace(at: now)
        let estimate: Double?
        if positionReliable, let words, words == 0 { estimate = 0 }
        else if positionReliable, speechOrigin != nil, let words, let pace { estimate = Double(words) / pace * 60 }
        else { estimate = nil }
        let headroom = estimate.map { remaining - $0 }
        let required = words.flatMap { words -> Double? in
            guard remaining > 0 else { return nil }
            let value = Double(words) / remaining * 60
            return value.isFinite ? value : nil
        }
        let state: LiveTimingState
        if startedAt == nil { state = .ready }
        else if remaining <= 0 { state = .overtime }
        else if words == nil { state = .noScript }
        else if !positionReliable { state = .locating }
        else if words == 0 { state = .complete }
        else if let headroom {
            state = headroom < 0 ? .behind : (headroom < max(10, Double(limitSeconds) * 0.05) ? .tight : .onTrack)
        } else { state = .estimating }
        return LiveTimingSnapshot(hasStarted: startedAt != nil, limitSeconds: limitSeconds,
                                  remainingSeconds: remaining, wordsPerMinute: pace,
                                  estimatedSeconds: startedAt == nil ? nil : estimate,
                                  headroomSeconds: startedAt == nil ? nil : headroom,
                                  requiredWordsPerMinute: required, state: state)
    }

    private func recentPace(at time: Double) -> Double? {
        guard let paceOrigin else { return nil }
        let lower = max(paceOrigin, time - Self.paceWindow)
        let duration = time - lower
        guard duration >= 5 else { return nil }
        let words = samples.reduce(0) { $0 + ($1.clipped(from: lower, to: time)?.words ?? 0) }
        guard words >= 5 - 0.000_001 else { return nil }
        return min(360, words / duration * 60)
    }
}

private struct PaceSample: Sendable {
    let session: Int
    let start: Double
    let end: Double
    let words: Double

    func shifted(by offset: Double) -> PaceSample {
        PaceSample(session: session, start: start + offset, end: end + offset, words: words)
    }

    func clipped(from lowerBound: Double, to upperBound: Double) -> PaceSample? {
        let lower = max(start, lowerBound)
        let upper = min(end, upperBound)
        guard lower < upper, end > start else { return nil }
        return PaceSample(session: session, start: lower, end: upper,
                          words: words * (upper - lower) / (end - start))
    }
}
