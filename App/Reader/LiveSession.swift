import Foundation
import KnowWhereAmICore
import Observation

@MainActor @Observable
final class LiveSession {
    private var timing: LiveTimingSession
    @ObservationIgnored private let now: @MainActor () -> Double

    init(limitSeconds: Int, now: @escaping @MainActor () -> Double) {
        timing = LiveTimingSession(limitSeconds: limitSeconds)
        self.now = now
    }

    func beginSpeech() { timing.beginSpeech(at: now()) }
    func endSpeech() { timing.endSpeech() }
    func alignAudio(startingAt audioTime: Double, observedAt instant: ContinuousClock.Instant, duration: Double) {
        let parts = instant.duration(to: .now).components
        let deliveryDelay = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        timing.alignAudio(startingAt: audioTime, at: now() - deliveryDelay - max(0, duration))
    }
    func record(_ chunk: SpeechChunk) { timing.record(chunk, at: now()) }
    func start() { timing.start(at: now()) }
    func restart() { timing.restart(at: now()) }
    func setLimit(_ seconds: Int) { timing.setLimit(seconds) }
    func reset(limitSeconds: Int) { timing = LiveTimingSession(limitSeconds: limitSeconds) }

    func snapshot(remainingWords: Int?, positionReliable: Bool) -> LiveTimingSnapshot {
        timing.snapshot(at: now(), remainingWords: remainingWords, positionReliable: positionReliable)
    }
}
