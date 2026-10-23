import Foundation
import Testing
@testable import KnowWhereAmICore

private func liveWords(_ count: Int) -> String {
    Array(repeating: "word", count: count).joined(separator: " ")
}

@Test func liveCountdownDefaultsToThreeMinutesAndDoesNotStartByItself() {
    let clock = LiveTimingSession()
    let value = clock.snapshot(at: 90, remainingWords: 100)
    #expect(value.remainingSeconds == 180)
    #expect(value.clockText == "3:00")
    #expect(!value.hasStarted)
    #expect(value.state == .ready)
    #expect(value.estimatedSeconds == nil)
}

@Test func liveCountdownContinuesWhenTheMicrophoneStops() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 10)
    clock.endSpeech()
    #expect(clock.snapshot(at: 80, remainingWords: 100).remainingSeconds == 110)
    #expect(clock.snapshot(at: 195, remainingWords: 100).clockText == "+0:05")
    #expect(clock.snapshot(at: 195, remainingWords: 100).state == .overtime)
}

@Test func liveChangingTheLimitPreservesElapsedTime() {
    var clock = LiveTimingSession()
    clock.start(at: 0)
    clock.setLimit(300)
    #expect(clock.snapshot(at: 60, remainingWords: 100).remainingSeconds == 240)
    clock.setLimit(30)
    #expect(clock.snapshot(at: 60, remainingWords: 100).remainingSeconds == -30)
}

@Test func liveForecastUsesSpokenWordsAndRemainingManuscriptWords() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(20), isFinal: false), at: 10)
    let value = clock.snapshot(at: 10, remainingWords: 80)
    #expect(value.wordsPerMinute == 120)
    #expect(value.estimatedSeconds == 40)
    #expect(value.headroomSeconds == 130)
    #expect(value.state == .onTrack)
    let skipped = clock.snapshot(at: 10, remainingWords: 20)
    #expect(skipped.wordsPerMinute == 120)
    #expect(skipped.estimatedSeconds == 10)
}

@Test func liveForecastIdentifiesBehindAndTightSchedules() {
    var clock = LiveTimingSession(limitSeconds: 60)
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 30, text: liveWords(60), isFinal: true), at: 30)
    let behind = clock.snapshot(at: 30, remainingWords: 90)
    #expect(behind.estimatedSeconds == 45)
    #expect(behind.headroomSeconds == -15)
    #expect(behind.requiredWordsPerMinute == 180)
    #expect(behind.state == .behind)
    #expect(clock.snapshot(at: 30, remainingWords: 50).state == .tight)
}

@Test func liveRepeatedAndRevisedAudioDoesNotInflatePace() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    let partial = SpeechChunk(start: 0, end: 10, text: liveWords(20), isFinal: false)
    clock.record(partial, at: 10)
    clock.record(partial, at: 10)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(18), isFinal: true), at: 10)
    clock.record(partial, at: 10)
    #expect(clock.snapshot(at: 10, remainingWords: 100).wordsPerMinute == 108)
}

@Test func liveAnEarlierFinalPreservesTheNonoverlappingProvisionalTail() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 20, text: liveWords(40), isFinal: false), at: 20)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(18), isFinal: true), at: 20)
    #expect(clock.snapshot(at: 20, remainingWords: 100).wordsPerMinute == 114)
}

@Test func liveWordTimingsReflectRecentSpeedInsteadOfAnEntireLongUtteranceAverage() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    let timings = [SpeechWordTiming(start: 0, end: 20, wordCount: 20),
                   SpeechWordTiming(start: 20, end: 40, wordCount: 60)]
    clock.record(SpeechChunk(start: 0, end: 40, text: liveWords(80), isFinal: false, wordTimings: timings), at: 40)
    #expect(clock.snapshot(at: 40, remainingWords: 100).wordsPerMinute == 140)
}

@Test func liveWordTimingRevisionsReplaceOnlyTheAffectedAudio() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    let timings = (0..<10).map { SpeechWordTiming(start: Double($0), end: Double($0 + 1)) }
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(10), isFinal: false, wordTimings: timings), at: 10)
    clock.record(SpeechChunk(start: 0, end: 5, text: liveWords(5), isFinal: true,
                            wordTimings: Array(timings.prefix(5))), at: 10)
    #expect(clock.snapshot(at: 10, remainingWords: 100).wordsPerMinute == 60)
}

@Test func livePausesReduceTheEffectiveRecentPaceWithoutPausingTheDeadline() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(20), isFinal: true), at: 10)
    clock.endSpeech()
    #expect(clock.snapshot(at: 20, remainingWords: 100).wordsPerMinute == 60)
    #expect(clock.snapshot(at: 45, remainingWords: 100).wordsPerMinute == nil)
    #expect(clock.snapshot(at: 45, remainingWords: 100).remainingSeconds == 135)
}

@Test func liveAStoppedMicrophoneDoesNotKeepPromisingAFinishTime() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(20), isFinal: true), at: 10)
    clock.endSpeech()
    let paused = clock.snapshot(at: 11, remainingWords: 80)
    #expect(paused.remainingSeconds == 169)
    #expect(paused.wordsPerMinute != nil)
    #expect(paused.estimatedSeconds == nil)
    #expect(paused.state == .estimating)
}

@Test func liveNewMicrophoneSessionsHaveSeparateAudioTimelines() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(20), isFinal: true), at: 10)
    clock.endSpeech()
    clock.beginSpeech(at: 15)
    clock.record(SpeechChunk(start: 0, end: 5, text: liveWords(10), isFinal: true), at: 20)
    #expect(clock.snapshot(at: 20, remainingWords: 100).wordsPerMinute == 90)
    #expect(clock.snapshot(at: 20, remainingWords: 100).remainingSeconds == 160)
}

@Test func liveAudioHostTimestampsAreMappedToTheCountdownClock() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 100)
    clock.alignAudio(startingAt: 8_000, at: 100)
    clock.record(SpeechChunk(start: 8_000, end: 8_010, text: liveWords(20), isFinal: false,
                            wordTimings: [SpeechWordTiming(start: 8_000, end: 8_010, wordCount: 20)]), at: 110)
    let value = clock.snapshot(at: 110, remainingWords: 80)
    #expect(value.wordsPerMinute == 120)
    #expect(value.estimatedSeconds == 40)
}

@Test func liveDelayedRecognitionCannotMakeStaleAudioLookLikeRecentSpeech() {
    var clock = LiveTimingSession(limitSeconds: 60)
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 5, text: liveWords(10), isFinal: true), at: 35)
    let value = clock.snapshot(at: 35, remainingWords: 5)
    #expect(value.wordsPerMinute == nil)
    #expect(value.estimatedSeconds == nil)
    #expect(value.state == .estimating)
}

@Test func liveRestartingTheCountdownKeepsRecentPace() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(20), isFinal: true), at: 10)
    clock.restart(at: 10)
    let value = clock.snapshot(at: 10, remainingWords: 100)
    #expect(value.remainingSeconds == 180)
    #expect(value.wordsPerMinute == 120)
}

@Test func liveWaitsForEnoughSpeechAndDoesNotPromiseATimeFromAnUnknownPosition() {
    var clock = LiveTimingSession()
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: 2, text: liveWords(3), isFinal: false), at: 2)
    #expect(clock.snapshot(at: 2, remainingWords: 100).state == .estimating)
    clock.record(SpeechChunk(start: 0, end: 10, text: liveWords(20), isFinal: false), at: 10)
    let unknown = clock.snapshot(at: 10, remainingWords: 100, positionReliable: false)
    #expect(unknown.state == .locating)
    #expect(unknown.estimatedSeconds == nil)
    #expect(clock.snapshot(at: 10, remainingWords: 0).state == .complete)
    #expect(clock.snapshot(at: 10, remainingWords: nil).state == .noScript)
}

@Test func liveInvalidTimesAndLimitsDoNotProduceInvalidForecasts() {
    var clock = LiveTimingSession()
    clock.start(at: .nan)
    #expect(!clock.snapshot(at: 0, remainingWords: 100).hasStarted)
    clock.setLimit(-1)
    #expect(clock.snapshot(at: 0, remainingWords: 100).remainingSeconds == 30)
    clock.beginSpeech(at: 0)
    clock.record(SpeechChunk(start: 0, end: .infinity, text: liveWords(20), isFinal: true), at: 10)
    #expect(clock.snapshot(at: 10, remainingWords: 100).wordsPerMinute == nil)
    #expect(clock.snapshot(at: .nan, remainingWords: 100).remainingSeconds.isFinite)
}

@Test func liveLegacyReaderSettingsGainTheDefaultLimitAndPersistIt() throws {
    let legacy = Data(#"{"title":"Talk","text":"Hello world.","fontSize":26}"#.utf8)
    let state = try JSONDecoder().decode(SavedReaderState.self, from: legacy)
    let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
    #expect(encoded?["liveTimeLimitSeconds"] as? Int == 180)
}

@Test func liveInvalidStoredDurationIsRejectedWithoutReplacingTheFile() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent("reader.json")
    let bytes = Data(#"{"title":"Talk","text":"Hello world.","fontSize":26,"liveTimeLimitSeconds":-3}"#.utf8)
    try bytes.write(to: url)
    #expect(throws: (any Error).self) { try ScriptStore(url: url).load() }
    #expect(try Data(contentsOf: url) == bytes)
}
