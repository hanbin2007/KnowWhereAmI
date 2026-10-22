import Foundation
import KnowWhereAmICore
import XCTest
@testable import KnowWhereAmI

@MainActor
final class ReaderModelTests: XCTestCase {
    private func makeModel(speech: ControlledSpeech = ControlledSpeech(), text: String = "We can create a better future together.") throws -> ReaderModel {
        let url = URL.temporaryDirectory.appending(path: "ReaderModelTests/\(UUID().uuidString)/script.json")
        let store = ScriptStore(url: url)
        try store.save(SavedReaderState(title: "Test", text: text))
        addTeardownBlock { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        return ReaderModel(store: store, speech: speech)
    }

    func testTextSizeChangesPersistToStorage() throws {
        let model = try makeModel()
        model.changeFontSize(by: 2)
        model.changeFontSize(by: 2)
        XCTAssertEqual(model.saved.fontSize, 30)
        for _ in 0..<20 { model.changeFontSize(by: 2) }
        XCTAssertEqual(model.saved.fontSize, 40)
    }

    func testLateResultsCannotAdvanceAfterPause() async throws {
        let speech = ControlledSpeech()
        let model = try makeModel(speech: speech)
        model.toggleListening()
        await waitForStart(speech)
        await speech.send(.listening)
        await speech.send(.transcript(SpeechChunk(start: 0, end: 1, text: "we can create", isFinal: false)))
        XCTAssertEqual(model.cursor, 2)
        model.pause()
        await waitForStop(model)
        await speech.send(.transcript(SpeechChunk(start: 0, end: 2, text: "we can create a better", isFinal: true)))
        XCTAssertEqual(model.cursor, 2)
        XCTAssertEqual(model.phase, .paused)
    }

    func testFinalPrefixDoesNotCommitLaterTentativeWords() async throws {
        let speech = ControlledSpeech()
        let model = try makeModel(speech: speech)
        model.toggleListening()
        await waitForStart(speech)
        await speech.send(.listening)
        await speech.send(.transcript(SpeechChunk(start: 0, end: 1, text: "we can", isFinal: false)))
        await speech.send(.transcript(SpeechChunk(start: 1, end: 2, text: "create a", isFinal: false)))
        await speech.send(.transcript(SpeechChunk(start: 0, end: 1, text: "we can", isFinal: true)))
        XCTAssertEqual(model.cursor, 3)
        XCTAssertEqual(model.confirmedCursor, 1)
        model.pause()
        await waitForStop(model)
    }

    func testRestartDuringStopEndsAtReadyRatherThanPaused() async throws {
        let speech = ControlledSpeech()
        let model = try makeModel(speech: speech)
        model.toggleListening()
        await waitForStart(speech)
        model.pause()
        model.restart()
        await waitForStop(model)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNil(model.cursor)
    }

    func testFailedSaveKeepsPreviousManuscript() throws {
        let model = try makeModel()
        let success = model.saveScript(title: "Too long", text: String(repeating: "a", count: 100_001))
        XCTAssertFalse(success)
        XCTAssertEqual(model.document.text, "We can create a better future together.")
        XCTAssertNotNil(model.alert)
    }

    func testFollowPreferenceIsNotOverriddenWhenListeningStarts() async throws {
        let speech = ControlledSpeech()
        let model = try makeModel(speech: speech)
        model.setFollowPreference(false)
        XCTAssertFalse(model.saved.followsPosition)
        model.toggleListening()
        await waitForStart(speech)
        XCTAssertFalse(model.followsPosition)
        model.pause()
        await waitForStop(model)
    }

    func testLateDownloadProgressDoesNotReplaceListeningState() async throws {
        let speech = ControlledSpeech()
        let model = try makeModel(speech: speech)
        model.toggleListening()
        await waitForStart(speech)
        await speech.send(.listening)
        await speech.send(.downloading(0.99))
        XCTAssertEqual(model.phase, .listening)
        model.pause()
        await waitForStop(model)
    }

    func testPauseWithoutActiveSessionDoesNotInventPausedState() throws {
        let model = try makeModel()
        model.pause()
        XCTAssertEqual(model.phase, .ready)
    }

    func testRepeatedMultiwordAudioIsTrackedAcrossRollingContext() async throws {
        let speech = ControlledSpeech()
        let model = try makeModel(speech: speech, text: Array(repeating: "Go", count: 100).joined(separator: " "))
        model.toggleListening()
        await waitForStart(speech)
        await speech.send(.listening)
        for index in 0..<20 {
            await speech.send(.transcript(SpeechChunk(start: Double(index), end: Double(index + 1), text: "go go go", isFinal: true)))
            XCTAssertEqual(model.cursor, (index + 1) * 3 - 1)
        }
        model.pause()
        await waitForStop(model)
    }

    private func waitForStart(_ speech: ControlledSpeech) async {
        for _ in 0..<100 {
            if await speech.hasStarted { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Speech session did not start")
    }

    private func waitForStop(_ model: ReaderModel) async {
        for _ in 0..<100 {
            if model.phase != .stopping { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Speech session did not stop")
    }
}

private actor ControlledSpeech: SpeechRecognizing {
    private var callback: (@Sendable (SpeechEvent) async -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?
    var hasStarted: Bool { callback != nil }

    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws {
        callback = onEvent
        await withCheckedContinuation { continuation = $0 }
    }

    func stop() async {
        continuation?.resume()
        continuation = nil
    }

    func send(_ event: SpeechEvent) async { await callback?(event) }
}
