import Foundation
import KnowWhereAmICore
import XCTest
@testable import KnowWhereAmI

@MainActor
final class ReaderExperienceTests: XCTestCase {
    private func fixture(text: String = "We can create a much better future together.") throws -> (ReaderModel, ScriptStore, ExperienceSpeech, TestTime) {
        let root = URL.temporaryDirectory.appending(path: "ReaderExperience/\(UUID().uuidString)")
        let legacy = ScriptStore(url: root.appendingPathComponent("reader.json"))
        try legacy.save(SavedReaderState(title: "Original", text: text))
        let speech = ExperienceSpeech()
        let time = TestTime()
        let model = ReaderModel(store: legacy, speech: speech, timeSource: { time.seconds })
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (model, legacy, speech, time)
    }

    func testLibraryMigratesCreatesAndSwitchesWithoutOverwritingScripts() throws {
        let (model, legacy, _, _) = try fixture()
        XCTAssertEqual(model.library.manuscripts.count, 1)
        let original = try XCTUnwrap(model.library.selectedID)
        XCTAssertTrue(model.createScript(title: "Second talk", text: "A separate manuscript stays separate."))
        let second = try XCTUnwrap(model.library.selectedID)
        XCTAssertNotEqual(original, second)
        XCTAssertEqual(model.library.manuscripts.count, 2)
        let restored = ReaderModel(store: legacy)
        XCTAssertEqual(restored.saved.title, "Second talk")
        XCTAssertTrue(restored.selectManuscript(original))
        XCTAssertEqual(restored.saved.title, "Original")
        XCTAssertEqual(restored.document.text, "We can create a much better future together.")
        XCTAssertTrue(restored.selectManuscript(second))
        XCTAssertEqual(restored.document.text, "A separate manuscript stays separate.")
    }

    func testDuplicateAndDeletingLastScriptPersistAnEmptyLibrary() throws {
        let (model, legacy, _, _) = try fixture()
        let original = try XCTUnwrap(model.library.selectedID)
        XCTAssertTrue(model.duplicateManuscript(original))
        let copy = try XCTUnwrap(model.library.selectedID)
        XCTAssertNotEqual(copy, original)
        XCTAssertEqual(model.saved.text, "We can create a much better future together.")
        XCTAssertTrue(model.deleteManuscript(original))
        XCTAssertEqual(model.library.manuscripts.count, 1)
        XCTAssertTrue(model.deleteManuscript(copy))
        let restored = ReaderModel(store: legacy)
        XCTAssertTrue(restored.library.manuscripts.isEmpty)
        XCTAssertNil(restored.library.selectedID)
        XCTAssertTrue(restored.document.words.isEmpty)
    }

    func testEstimatedMetricsExcludePreparationAndPauseAndPersistReport() async throws {
        let (model, legacy, speech, time) = try fixture()
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        time.seconds = 40
        await speech.send(.listening)
        time.seconds = 60
        await speech.send(.transcript(SpeechChunk(start: 0, end: 5, text: "we can create a better", isFinal: true)))
        model.pause()
        await waitForStop(model)
        time.seconds = 160
        model.toggleListening()
        await waitForStarts(speech, count: 2)
        await speech.send(.listening)
        time.seconds = 170
        await speech.send(.transcript(SpeechChunk(start: 0, end: 2, text: "future together", isFinal: true)))
        for _ in 0..<100 {
            if !model.history.isEmpty { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        let result = try XCTUnwrap(model.history.first)
        XCTAssertEqual(result.statistics.elapsedSeconds, 30, accuracy: 0.001)
        XCTAssertEqual(result.statistics.spokenWords, 7)
        XCTAssertEqual(result.statistics.wordsPerMinute ?? -1, 14, accuracy: 0.01)
        XCTAssertEqual(result.statistics.missedWords, 1)
        XCTAssertEqual(result.statistics.omittedWordIndices, [4])
        XCTAssertEqual(ReaderModel(store: legacy).history.first?.id, result.id)
    }

    func testLiveModeDoesNotCreateScoresOrStopAtTheLastWord() async throws {
        let (model, _, speech, _) = try fixture()
        model.setMode(.live)
        XCTAssertEqual(model.mode, .live)
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        await speech.send(.transcript(SpeechChunk(start: 0, end: 4, text: "we can create a much better future together", isFinal: true)))
        XCTAssertEqual(model.phase, .listening)
        XCTAssertTrue(model.history.isEmpty)
        XCTAssertEqual(model.statistics.spokenWords, 0)
        model.pause()
        await waitForStop(model)
    }

    func testFinishingDrainsTheLastFinalResultBeforeSavingTheReport() async throws {
        let (model, _, speech, time) = try fixture()
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        time.seconds = 10
        await speech.send(.transcript(SpeechChunk(start: 0, end: 3, text: "we can create a much", isFinal: false)))
        await speech.queueFinalOnFinish(SpeechChunk(start: 0, end: 3, text: "we can create a much", isFinal: true))
        model.finishRehearsal()
        for _ in 0..<100 {
            if model.phase == .finished { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let report = try XCTUnwrap(model.history.first)
        XCTAssertEqual(report.statistics.spokenWords, 5)
        XCTAssertEqual(report.statistics.matchedWords, 5)
        XCTAssertEqual(report.statistics.elapsedSeconds, 10, accuracy: 0.001)
        XCTAssertEqual(model.phase, .finished)
    }

    func testManualScrollTemporarilySuspendsThenRestoresEnabledFollow() async throws {
        let (model, _, speech, _) = try fixture()
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        model.beginManualScroll()
        XCTAssertFalse(model.followsPosition)
        model.endManualScroll()
        try await Task.sleep(for: .seconds(2.8))
        XCTAssertTrue(model.followsPosition)
        model.pause()
        await waitForStop(model)
    }

    func testLiveParagraphRescueAndExplicitPauseCannotRestartMicrophone() async throws {
        let (model, _, speech, _) = try fixture(text: "Opening words are here.\n\nA second paragraph begins.\n\nClosing words are here.")
        model.setMode(.live)
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        model.jumpParagraph(1)
        model.pause()
        await waitForStop(model)
        XCTAssertEqual(model.cursor, 4)
        let starts = await speech.startCount
        XCTAssertEqual(starts, 1)
    }

    func testFailedScriptTransitionDoesNotFreezeAnOngoingRehearsal() async throws {
        let (model, _, speech, time) = try fixture()
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        time.seconds = 5
        await speech.send(.transcript(SpeechChunk(start: 0, end: 2, text: "we can create a much", isFinal: true)))
        XCTAssertFalse(model.saveScript(title: "Invalid", text: String(repeating: "a", count: 100_001)))
        await waitForStop(model)
        model.alert = nil
        model.toggleListening()
        await waitForStarts(speech, count: 2)
        await speech.send(.listening)
        time.seconds = 10
        await speech.send(.transcript(SpeechChunk(start: 0, end: 2, text: "better future together", isFinal: true)))
        for _ in 0..<100 {
            if model.phase == .finished { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.history.count, 1)
        XCTAssertEqual(model.history.first?.statistics.spokenWords, 8)
        XCTAssertEqual(model.history.first?.statistics.matchedWords, 8)
    }

    func testNextParagraphAtTheEndDoesNotMoveBackwardOrRestartSpeech() async throws {
        let (model, _, speech, _) = try fixture(text: "First paragraph here.\n\nLast paragraph ends here.")
        model.setMode(.live)
        model.selectWord(5)
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        model.jumpParagraph(1)
        XCTAssertEqual(model.cursor, 5)
        XCTAssertEqual(model.phase, .listening)
        model.pause()
        await waitForStop(model)
    }

    func testDeletingAReportDoesNotResurrectItOnRestartOrModeChange() async throws {
        let (model, _, speech, time) = try fixture()
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        time.seconds = 10
        await speech.send(.transcript(SpeechChunk(start: 0, end: 3, text: "we can create a much better future together", isFinal: true)))
        for _ in 0..<100 {
            if model.phase == .finished { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let id = try XCTUnwrap(model.history.first?.id)
        XCTAssertTrue(model.deleteRehearsal(id))
        model.setMode(.live)
        model.setMode(.rehearsal)
        model.restart()
        XCTAssertTrue(model.history.isEmpty)
    }

    func testOpeningAnOldReportStopsTheMicrophoneAndRejectsHiddenScoring() async throws {
        let (model, _, speech, time) = try fixture()
        model.toggleListening()
        await waitForStarts(speech, count: 1)
        await speech.send(.listening)
        time.seconds = 3
        await speech.send(.transcript(SpeechChunk(start: 0, end: 2, text: "we can create", isFinal: true)))
        model.finishRehearsal(presentReport: false)
        for _ in 0..<100 {
            if model.phase == .finished { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let record = try XCTUnwrap(model.history.first)
        model.toggleListening()
        await waitForStarts(speech, count: 2)
        await speech.send(.listening)
        model.showReport(record)
        await waitForStop(model)
        await speech.send(.transcript(SpeechChunk(start: 0, end: 2, text: "we can create a much", isFinal: true)))
        XCTAssertEqual(model.phase, .paused)
        XCTAssertEqual(model.statistics.spokenWords, 0)
        XCTAssertEqual(model.presentedReport?.id, record.id)
    }

    private func waitForStarts(_ speech: ExperienceSpeech, count: Int) async {
        for _ in 0..<100 {
            if await speech.startCount >= count { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Speech did not start")
    }

    private func waitForStop(_ model: ReaderModel) async {
        for _ in 0..<100 {
            if model.phase != .stopping { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Speech did not stop")
    }
}

@MainActor
private final class TestTime { var seconds: Double = 0 }

private actor ExperienceSpeech: SpeechRecognizing {
    private var callback: (@Sendable (SpeechEvent) async -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var startCount = 0
    private var finalOnFinish: SpeechChunk?
    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws {
        startCount += 1
        callback = onEvent
        await withCheckedContinuation { continuation = $0 }
    }
    func stop() async { continuation?.resume(); continuation = nil }
    func finish() async {
        if let finalOnFinish { await send(.transcript(finalOnFinish)); self.finalOnFinish = nil }
        await stop()
    }
    func queueFinalOnFinish(_ chunk: SpeechChunk) { finalOnFinish = chunk }
    func send(_ event: SpeechEvent) async { await callback?(event) }
}
