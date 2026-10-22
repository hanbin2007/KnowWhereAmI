import Testing
@testable import KnowWhereAmICore

@Test func partialsReplaceRatherThanDuplicateText() {
    var buffer = TranscriptBuffer()
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "we can", isFinal: false))
    buffer.ingest(SpeechChunk(start: 0, end: 2, text: "we can create", isFinal: false))
    #expect(buffer.text == "we can create")
    buffer.ingest(SpeechChunk(start: 0, end: 2, text: "we can create", isFinal: true))
    buffer.ingest(SpeechChunk(start: 2, end: 3, text: "a better future", isFinal: false))
    #expect(buffer.text == "we can create a better future")
}

@Test func emptyPartialRevokesItsPreviousAudioRange() {
    var buffer = TranscriptBuffer()
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "we can", isFinal: true))
    buffer.ingest(SpeechChunk(start: 1, end: 2, text: "create", isFinal: false))
    buffer.ingest(SpeechChunk(start: 1, end: 2, text: "", isFinal: false))
    #expect(buffer.text == "we can")
}

@Test func stalePartialsCannotOverwriteFinalizedAudio() {
    var buffer = TranscriptBuffer()
    let final = SpeechChunk(start: 0, end: 2, text: "we can create", isFinal: true)
    buffer.ingest(final)
    buffer.ingest(final)
    let accepted = buffer.ingest(SpeechChunk(start: 0, end: 1, text: "wrong", isFinal: false))
    #expect(!accepted)
    #expect(buffer.text == "we can create")
}

@Test func finalForPrefixPreservesNonOverlappingNewerPartial() {
    var buffer = TranscriptBuffer()
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "we can", isFinal: false))
    buffer.ingest(SpeechChunk(start: 1, end: 2, text: "create", isFinal: false))
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "we could", isFinal: true))
    #expect(buffer.text == "we could create")
}

@Test func invalidTimeRangesAreIgnoredAndResetClearsHistory() {
    var buffer = TranscriptBuffer()
    let nanAccepted = buffer.ingest(SpeechChunk(start: .nan, end: 2, text: "bad", isFinal: false))
    let reversedAccepted = buffer.ingest(SpeechChunk(start: 3, end: 2, text: "bad", isFinal: false))
    #expect(!nanAccepted)
    #expect(!reversedAccepted)
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "hello", isFinal: true))
    buffer.reset()
    #expect(buffer.text.isEmpty)
}

@Test func emptyFinalClosesItsAudioRangeAgainstLatePartials() {
    var buffer = TranscriptBuffer()
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "we can", isFinal: true))
    buffer.ingest(SpeechChunk(start: 1, end: 2, text: "create", isFinal: false))
    buffer.ingest(SpeechChunk(start: 1, end: 2, text: "", isFinal: true))
    let accepted = buffer.ingest(SpeechChunk(start: 1, end: 2, text: "create", isFinal: false))
    #expect(!accepted)
    #expect(buffer.text == "we can")
}
