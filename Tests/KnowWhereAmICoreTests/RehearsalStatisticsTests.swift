import Foundation
import Testing
@testable import KnowWhereAmICore

@Test func finalEvidenceTracesOmissionsRatherThanTreatingCursorAsCoverage() throws {
    let document = ScriptDocument(text: "Today we will explore the beautiful northern coastline together.")
    var tracker = ScriptTracker(document: document)
    let result = tracker.consume("today we explore the northern coastline", isFinal: true)
    let evidence = try #require(result.evidence)
    #expect(evidence.matchedWordIndices == [0, 1, 3, 4, 6, 7])
    #expect(evidence.assessedWordIndices == Set(0...7))

    var accumulator = RehearsalAccumulator(document: document)
    accumulator.recordFinal(text: "today we explore the northern coastline", evidence: evidence)
    let statistics = accumulator.snapshot(elapsedSeconds: 30)
    #expect(statistics.spokenWords == 6)
    #expect(statistics.wordsPerMinute == 12)
    #expect(statistics.matchedWords == 6)
    #expect(statistics.missedWords == 2)
    #expect(statistics.assessedWords == 8)
    #expect(statistics.unassessedWords == 1)
    #expect(statistics.accuracy == 0.75)
    #expect(statistics.omittedWordIndices == [2, 5])
}

@Test func onlyMatchedFinalResultsCarryAlignmentEvidence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    #expect(tracker.consume("we can create", isFinal: false).evidence == nil)
    #expect(tracker.consume("we can create", isFinal: true).evidence != nil)
    #expect(tracker.consume("purple umbrella banana", isFinal: true).evidence == nil)
    #expect(tracker.revokeTentative().evidence == nil)
    tracker.select(wordIndex: 4)
    #expect(tracker.consume("", isFinal: true).evidence == nil)
}

@Test func evidenceMapsContractionsAndNumbersToOriginalWords() throws {
    let document = ScriptDocument(text: "She's invited 42 people and we don't need more.")
    var tracker = ScriptTracker(document: document)
    let result = tracker.consume("she has invited forty two people and we do not need more", isFinal: true)
    let evidence = try #require(result.evidence)
    #expect(evidence.matchedWordIndices == Set(0...8))
    #expect(evidence.assessedWordIndices == Set(0...8))
}

@Test func finalEvidenceIncludesAnEntireSegmentLongerThanCursorWindow() throws {
    let text = "The harbor wakes before sunrise while quiet streets gather early workers beside the station. A baker carries fresh bread across the square and opens every window toward the water. Soon bicycles pass the market where neighbors greet familiar faces and prepare another busy morning together under clear skies near our beautiful northern coastline today."
    let document = ScriptDocument(text: text)
    #expect(document.words.count == 54)
    var tracker = ScriptTracker(document: document)
    let evidence = try #require(tracker.consume(text, isFinal: true).evidence)
    #expect(evidence.matchedWordIndices == Set(0...53))
    var accumulator = RehearsalAccumulator(document: document)
    accumulator.recordFinal(text: text, evidence: evidence)
    #expect(accumulator.snapshot(elapsedSeconds: 60).missedWords == 0)
}

@Test func aFinalChunkAssessesOnlyItsOwnSegmentNotTentativeBufferTail() throws {
    let document = ScriptDocument(text: "We can create a better future together.")
    var tracker = ScriptTracker(document: document)
    let result = tracker.consume("we can create a better", isFinal: true, hypothesisID: 0, segmentText: "we can create")
    #expect(result.wordIndex == 2)
    #expect(result.evidence?.matchedWordIndices == Set(0...2))
    #expect(result.evidence?.assessedWordIndices == Set(0...2))
}

@Test func exceptionallyLongExactFinalDoesNotTurnItsEarlierWordsIntoOmissions() throws {
    let segment = Array(repeating: "go", count: 600).joined(separator: " ")
    let document = ScriptDocument(text: "begin \(segment)")
    var tracker = ScriptTracker(document: document)
    var accumulator = RehearsalAccumulator(document: document)
    accumulator.recordFinal(text: "begin", evidence: tracker.consume("begin", isFinal: true).evidence)
    let evidence = try #require(tracker.consume(segment, isFinal: true).evidence)
    accumulator.recordFinal(text: segment, evidence: evidence)
    let statistics = accumulator.snapshot(elapsedSeconds: 60)
    #expect(statistics.matchedWords == 601)
    #expect(statistics.missedWords == 0)
}

@Test func exceptionallyLongInexactFinalIsUnassessedRatherThanSuffixTruncated() {
    let repeated = Array(repeating: "go", count: 300).joined(separator: " ")
    let document = ScriptDocument(text: "begin \(repeated) special \(repeated) finish now")
    let segment = "\(repeated) \(repeated) finish now"
    var tracker = ScriptTracker(document: document)
    var accumulator = RehearsalAccumulator(document: document)
    accumulator.recordFinal(text: "begin", evidence: tracker.consume("begin", isFinal: true).evidence)
    let update = tracker.consume(segment, isFinal: true)
    #expect(update.isMatched)
    #expect(update.evidence == nil)
    accumulator.recordFinal(text: segment, evidence: update.evidence)
    let statistics = accumulator.snapshot(elapsedSeconds: 60)
    #expect(statistics.spokenWords == 603)
    #expect(statistics.matchedWords == 1)
    #expect(statistics.missedWords == 0)
}

@Test func repeatedFinalizedAudioIsCountedOnlyWhenTranscriptBufferAcceptsIt() {
    let document = ScriptDocument(text: "we can create")
    var tracker = ScriptTracker(document: document)
    var accumulator = RehearsalAccumulator(document: document)
    var buffer = TranscriptBuffer()
    let chunk = SpeechChunk(start: 0, end: 1, text: "we can create", isFinal: true)
    for _ in 0..<2 where buffer.ingest(chunk) {
        let result = tracker.consume(buffer.text, isFinal: true, hypothesisID: buffer.hypothesisID, segmentText: chunk.text)
        accumulator.recordFinal(text: chunk.text, evidence: result.evidence)
    }
    let statistics = accumulator.snapshot(elapsedSeconds: 10)
    #expect(statistics.spokenWords == 3)
    #expect(statistics.matchedWords == 3)
    #expect(statistics.wordsPerMinute == 18)
}

@Test func substitutionsAreAssessedButNotCountedAsMatchedWords() throws {
    let document = ScriptDocument(text: "Today we will explore northern coastline together.")
    var tracker = ScriptTracker(document: document)
    let evidence = try #require(tracker.consume("today we will discuss northern coastline together", isFinal: true).evidence)
    var accumulator = RehearsalAccumulator(document: document)
    accumulator.recordFinal(text: "today we will discuss northern coastline together", evidence: evidence)
    let statistics = accumulator.snapshot(elapsedSeconds: 60)
    #expect(statistics.matchedWords == 6)
    #expect(statistics.missedWords == 1)
    #expect(statistics.omittedWordIndices == [3])
    #expect(statistics.accuracy == Double(6) / 7)
}

@Test func rereadingRepairsEstimatedMissesWithoutDuplicatingScriptCoverage() {
    let document = ScriptDocument(text: "One small step can change our future together.")
    var accumulator = RehearsalAccumulator(document: document)
    let first = AlignmentEvidence(matchedWordIndices: [0, 2, 3], assessedWordIndices: [0, 1, 2, 3])
    accumulator.recordFinal(text: "one step can", evidence: first)
    accumulator.recordFinal(text: "small step can", evidence: AlignmentEvidence(matchedWordIndices: [1, 2, 3], assessedWordIndices: [1, 2, 3]))
    let statistics = accumulator.snapshot(elapsedSeconds: 30)
    #expect(statistics.spokenWords == 6)
    #expect(statistics.wordsPerMinute == 12)
    #expect(statistics.matchedWords == 4)
    #expect(statistics.missedWords == 0)
    #expect(statistics.unassessedWords == 4)
}

@Test func speechSupportedForwardJumpCanAssessItsBracketedGap() {
    var accumulator = RehearsalAccumulator(document: ScriptDocument(text: "zero one two three four five six seven eight nine"))
    accumulator.recordFinal(text: "zero one", evidence: AlignmentEvidence(matchedWordIndices: [0, 1], assessedWordIndices: [0, 1]))
    accumulator.recordFinal(text: "five six", evidence: AlignmentEvidence(matchedWordIndices: [5, 6], assessedWordIndices: [5, 6]))
    let statistics = accumulator.snapshot(elapsedSeconds: 10)
    #expect(statistics.omittedWordIndices == [2, 3, 4])
    #expect(statistics.unassessedWords == 3)
}

@Test func explicitManualSeekDoesNotAssessTheSkippedGap() {
    var accumulator = RehearsalAccumulator(document: ScriptDocument(text: "zero one two three four five six seven eight nine"))
    accumulator.recordFinal(text: "zero one", evidence: AlignmentEvidence(matchedWordIndices: [0, 1], assessedWordIndices: [0, 1]))
    accumulator.setAnchor(wordIndex: 5)
    accumulator.recordFinal(text: "five six", evidence: AlignmentEvidence(matchedWordIndices: [5, 6], assessedWordIndices: [5, 6]))
    let statistics = accumulator.snapshot(elapsedSeconds: 10)
    #expect(statistics.omittedWordIndices.isEmpty)
    #expect(statistics.assessedWordIndices == [0, 1, 5, 6])
    #expect(statistics.unassessedWords == 6)
}

@Test func startingMidManuscriptLeavesTheUnreadPrefixAndTailUnassessed() {
    var accumulator = RehearsalAccumulator(document: ScriptDocument(text: "zero one two three four five six seven eight nine"), startWord: 5)
    accumulator.recordFinal(text: "five six", evidence: AlignmentEvidence(matchedWordIndices: [5, 6], assessedWordIndices: [5, 6]))
    #expect(accumulator.snapshot(elapsedSeconds: 10).assessedWordIndices == [5, 6])
    #expect(accumulator.snapshot(elapsedSeconds: 10).missedWords == 0)
}

@Test func emptyAndUnmatchedFinalSpeechCannotInventAccuracy() {
    var accumulator = RehearsalAccumulator(document: ScriptDocument(text: "we can create"))
    #expect(accumulator.snapshot(elapsedSeconds: 0).wordsPerMinute == nil)
    #expect(accumulator.snapshot(elapsedSeconds: 10).accuracy == nil)
    accumulator.recordFinal(text: "purple umbrella banana", evidence: nil)
    let statistics = accumulator.snapshot(elapsedSeconds: 15)
    #expect(statistics.spokenWords == 3)
    #expect(statistics.wordsPerMinute == 12)
    #expect(statistics.accuracy == nil)
    #expect(statistics.assessedWords == 0)
    #expect(statistics.unassessedWords == 3)
    #expect(statistics.missedWords == 0)
}

@Test func reusedEvidenceDoesNotInflateCoverageOrAllowInvalidIndices() {
    var accumulator = RehearsalAccumulator(document: ScriptDocument(text: "we can create"))
    let evidence = AlignmentEvidence(matchedWordIndices: [-1, 0, 1, 8], assessedWordIndices: [-1, 0, 8])
    accumulator.recordFinal(text: "we can", evidence: evidence)
    accumulator.recordFinal(text: "we can", evidence: evidence)
    let statistics = accumulator.snapshot(elapsedSeconds: 20)
    #expect(statistics.spokenWords == 4)
    #expect(statistics.matchedWordIndices == [0, 1])
    #expect(statistics.assessedWordIndices == [0, 1])
    #expect(statistics.accuracy == 1)
    #expect(statistics.unassessedWords == 1)
}

@Test func suppliedActiveElapsedTimeControlsSpeedAndInvalidTimeIsSanitized() {
    var accumulator = RehearsalAccumulator(document: ScriptDocument(text: "I'm ready"))
    accumulator.recordFinal(text: "I'm ready", evidence: nil)
    #expect(accumulator.snapshot(elapsedSeconds: 10).wordsPerMinute == 12)
    #expect(accumulator.snapshot(elapsedSeconds: 0).wordsPerMinute == nil)
    #expect(accumulator.snapshot(elapsedSeconds: -.infinity).elapsedSeconds == 0)
    #expect(accumulator.snapshot(elapsedSeconds: .nan).wordsPerMinute == nil)
}

@Test func rehearsalHistoryRoundTripsAllRecordsWithoutRetentionTruncation() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = RehearsalHistoryStore(url: directory.appendingPathComponent("history.json"))
    #expect(try store.load().isEmpty)
    let manuscriptID = UUID()
    var accumulator = RehearsalAccumulator(document: ScriptDocument(text: "Hello world"))
    accumulator.recordFinal(text: "hello world", evidence: AlignmentEvidence(matchedWordIndices: [0, 1], assessedWordIndices: [0, 1]))
    let statistics = accumulator.snapshot(elapsedSeconds: 2)
    let records = (0..<205).map { index in
        RehearsalRecord(manuscriptID: manuscriptID, title: "Run \(index)", scriptText: "Hello world", startedAt: Date(timeIntervalSince1970: Double(index)), endedAt: Date(timeIntervalSince1970: Double(index + 2)), statistics: statistics)
    }
    try store.save(records)
    #expect(try store.load() == records)
}

@Test func malformedHistoryIsReportedWithoutReplacingIt() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.json")
    let original = Data("not valid JSON".utf8)
    try original.write(to: url)
    let store = RehearsalHistoryStore(url: url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: url) == original)
    let record = RehearsalRecord(manuscriptID: UUID(), title: "Bad", scriptText: "text", startedAt: Date(timeIntervalSinceReferenceDate: .nan), endedAt: Date(), statistics: RehearsalAccumulator(document: ScriptDocument(text: "text")).snapshot(elapsedSeconds: 0))
    #expect(throws: (any Error).self) { try store.save([record]) }
    #expect(try Data(contentsOf: url) == original)
}
