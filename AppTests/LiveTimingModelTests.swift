import CoreMedia
import Foundation
import KnowWhereAmICore
import Speech
import XCTest
@testable import KnowWhereAmI

@MainActor
final class LiveTimingModelTests: XCTestCase {
    private func fixture() throws -> (ReaderModel, ScriptStore, LiveTestSpeech, LiveTestTime) {
        let root = URL.temporaryDirectory.appending(path: "LiveTimingTests/\(UUID().uuidString)")
        let store = ScriptStore(url: root.appendingPathComponent("reader.json"))
        try store.save(SavedReaderState(title: "Live talk", text: Array(repeating: "Word", count: 100).joined(separator: " ")))
        let time = LiveTestTime()
        let speech = LiveTestSpeech()
        let model = ReaderModel(store: store, speech: speech, timeSource: { time.seconds })
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (model, store, speech, time)
    }

    private func begin(_ model: ReaderModel, _ speech: LiveTestSpeech) async throws {
        model.toggleListening()
        for _ in 0..<100 {
            if await speech.ready { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        await speech.send(.listening)
    }

    func testLiveCountdownStartsAfterPreparationAndContinuesAfterMicrophonePause() async throws {
        let (model, _, speech, time) = try fixture()
        model.setMode(.live)
        time.seconds = 40
        try await begin(model, speech)
        XCTAssertEqual(model.liveTimer.remainingSeconds, 180)
        model.pause()
        time.seconds = 70
        XCTAssertEqual(model.liveTimer.remainingSeconds, 150)
        XCTAssertTrue(model.history.isEmpty)
    }

    func testLiveLimitPersistsPerManuscriptAndDoesNotResetTheActiveClock() async throws {
        let (model, store, speech, time) = try fixture()
        model.setMode(.live)
        try await begin(model, speech)
        time.seconds = 60
        XCTAssertTrue(model.setLiveTimeLimit(300))
        XCTAssertEqual(model.liveTimer.remainingSeconds, 240)
        XCTAssertEqual(ReaderModel(store: store).saved.liveTimeLimitSeconds, 300)
        XCTAssertFalse(model.setLiveTimeLimit(-1))
        XCTAssertEqual(model.saved.liveTimeLimitSeconds, 300)
        model.pause()
    }

    func testManualRescueChangesTheRemainingTailButCannotInventPaceOrResetTime() async throws {
        let (model, _, speech, time) = try fixture()
        model.setMode(.live)
        try await begin(model, speech)
        time.seconds = 10
        await speech.send(.transcript(SpeechChunk(start: 0, end: 10,
            text: Array(repeating: "word", count: 20).joined(separator: " "), isFinal: false)))
        XCTAssertEqual(model.liveTimer.wordsPerMinute, 120)
        XCTAssertEqual(model.liveTimer.estimatedSeconds, 40)
        model.selectWord(50)
        model.pause()
        for _ in 0..<100 {
            if model.phase != .stopping { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.liveTimer.remainingSeconds, 170)
        XCTAssertEqual(model.liveTimer.wordsPerMinute, 120)
        XCTAssertNil(model.liveTimer.estimatedSeconds)
        try await begin(model, speech)
        XCTAssertEqual(model.liveTimer.estimatedSeconds, 25)
        model.pause()
        XCTAssertTrue(model.history.isEmpty)
    }

    func testModeSwitchingKeepsTheLiveDeadlineAndRestartExplicitlyClearsIt() throws {
        let (model, _, _, time) = try fixture()
        model.setMode(.live)
        model.startLiveCountdown()
        time.seconds = 30
        model.setMode(.rehearsal)
        time.seconds = 50
        model.setMode(.live)
        XCTAssertEqual(model.liveTimer.remainingSeconds, 130)
        model.restart()
        XCTAssertFalse(model.liveTimer.hasStarted)
        XCTAssertEqual(model.liveTimer.remainingSeconds, 180)
    }

    func testStartingTheCountdownDoesNotStartTheMicrophone() async throws {
        let (model, _, speech, time) = try fixture()
        model.setMode(.live)
        model.startLiveCountdown()
        time.seconds = 5
        XCTAssertEqual(model.liveTimer.remainingSeconds, 175)
        XCTAssertEqual(model.phase, .ready)
        let started = await speech.ready
        XCTAssertFalse(started)
        model.restartLiveCountdown()
        XCTAssertEqual(model.liveTimer.remainingSeconds, 180)
    }

    func testSelectingAnotherManuscriptResetsTimeButEditingTheSameOneDoesNot() throws {
        let (model, _, _, time) = try fixture()
        model.setMode(.live)
        model.startLiveCountdown()
        time.seconds = 20
        XCTAssertTrue(model.saveScript(title: "Revised", text: "A revised script keeps its existing deadline."))
        XCTAssertEqual(model.liveTimer.remainingSeconds, 160)
        XCTAssertTrue(model.createScript(title: "Next talk", text: "A new presentation has a new clock."))
        XCTAssertFalse(model.liveTimer.hasStarted)
        XCTAssertEqual(model.saved.liveTimeLimitSeconds, 180)
    }

    func testRehearsalDoesNotStartALiveClock() async throws {
        let (model, _, speech, time) = try fixture()
        try await begin(model, speech)
        time.seconds = 20
        XCTAssertFalse(model.liveTimer.hasStarted)
        model.pause()
    }

    func testSpeechBuilderPreservesWordAudioTimings() {
        var first = AttributedString("hello")
        first.audioTimeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 1, preferredTimescale: 600))
        var second = AttributedString("world")
        second.audioTimeRange = CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 600),
                                          duration: CMTime(seconds: 1, preferredTimescale: 600))
        let chunk = SpeechChunkBuilder.make(text: first + AttributedString(" ") + second,
            range: CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600)), isFinal: false)
        XCTAssertEqual(chunk.text, "hello world")
        XCTAssertEqual(chunk.wordTimings, [SpeechWordTiming(start: 0, end: 1), SpeechWordTiming(start: 1, end: 2)])
    }

    func testLivePaceUsesTheCaptureClockRatherThanTheRecognitionDeliveryTime() async throws {
        let (model, _, speech, time) = try fixture()
        model.setMode(.live)
        try await begin(model, speech)
        await speech.send(.audioStarted(time: 8_000, observedAt: .now, duration: 0))
        time.seconds = 35
        await speech.send(.transcript(SpeechChunk(start: 8_000, end: 8_005,
            text: Array(repeating: "word", count: 10).joined(separator: " "), isFinal: true)))
        XCTAssertNil(model.liveTimer.wordsPerMinute)
        XCTAssertNil(model.liveTimer.estimatedSeconds)
        model.pause()
    }
}

@MainActor private final class LiveTestTime { var seconds: Double = 0 }

private actor LiveTestSpeech: SpeechRecognizing {
    private var callback: (@Sendable (SpeechEvent) async -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?
    var ready: Bool { callback != nil }
    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws {
        callback = onEvent
        await withCheckedContinuation { continuation = $0 }
    }
    func send(_ event: SpeechEvent) async { await callback?(event) }
    func stop() async { callback = nil; continuation?.resume(); continuation = nil }
}
