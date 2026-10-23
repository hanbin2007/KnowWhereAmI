import Testing
@testable import KnowWhereAmICore

private let adaptiveScript = "Opening remarks explain our purpose clearly. Careful planning helps every participant understand all important practical constraints before proceeding. Blue lanterns glow."

@Test func adaptiveNearbyWordCanMovePastTwoASROmissions() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    #expect(tracker.consume("we can", isFinal: true, hypothesisID: 0).wordIndex == 1)
    let update = tracker.consume("better", isFinal: false, hypothesisID: 1, segmentText: "better")
    #expect(update.wordIndex == 4)
    #expect(update.isMatched)
    #expect(update.confirmedWordIndex == 1)
}

@Test func adaptiveNearbySpeechCanTolerateOneMisrecognizedToken() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    #expect(tracker.consume("we can", isFinal: true, hypothesisID: 0).wordIndex == 1)
    let update = tracker.consume("purple better", isFinal: false, hypothesisID: 1, segmentText: "purple better")
    #expect(update.wordIndex == 4)
    #expect(update.isMatched)
}

@Test func adaptiveMediumJumpUsesTwoFreshWords() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Opening remarks explain our purpose clearly. We can build a reliable future together."))
    tracker.select(wordIndex: 5)
    let update = tracker.consume("reliable future", isFinal: false, hypothesisID: 1, segmentText: "reliable future")
    #expect(update.wordIndex == 11)
    #expect(update.isMatched)
}

@Test func adaptiveRecoveryAccumulatesDistinctShortAudio() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Opening remarks explain our purpose clearly. We can build a reliable future together."))
    tracker.select(wordIndex: 5)
    #expect(tracker.consume("reliable", isFinal: false, hypothesisID: 1, segmentText: "reliable", audioRange: 0..<1).wordIndex == 5)
    #expect(tracker.consume("future", isFinal: false, hypothesisID: 2, segmentText: "future", audioRange: 1..<2).wordIndex == 11)
    #expect(tracker.consume("together", isFinal: false, hypothesisID: 3, segmentText: "together", audioRange: 2..<3).wordIndex == 12)
    #expect(tracker.confirmedWordIndex == 5)
}

@Test func adaptiveFarJumpNeedsThreeFreshWords() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    tracker.select(wordIndex: 5)
    #expect(tracker.consume("blue", isFinal: false, hypothesisID: 1, segmentText: "blue", audioRange: 0..<1).wordIndex == 5)
    #expect(tracker.consume("lanterns", isFinal: false, hypothesisID: 2, segmentText: "lanterns", audioRange: 1..<2).wordIndex == 5)
    let update = tracker.consume("glow", isFinal: true, hypothesisID: 3, segmentText: "glow", audioRange: 2..<3)
    #expect(update.wordIndex == 20)
    #expect(update.evidence?.matchedWordIndices == Set([20]))
    #expect(update.evidence?.assessedWordIndices == Set([20]))
}

@Test func adaptiveRepeatedRevisionDoesNotCountAsAdditionalWords() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    tracker.select(wordIndex: 5)
    for _ in 0..<10 {
        let update = tracker.consume("blue", isFinal: false, hypothesisID: 1, segmentText: "blue", audioRange: 0..<1)
        #expect(update.wordIndex == 5)
        #expect(!update.isMatched)
    }
}

@Test func adaptiveWindowReplacesExpandedHypothesesInsteadOfDuplicatingThem() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    tracker.select(wordIndex: 5)
    #expect(tracker.consume("blue", isFinal: false, hypothesisID: 1, segmentText: "blue", audioRange: 0..<1).wordIndex == 5)
    #expect(tracker.consume("blue lanterns", isFinal: false, hypothesisID: 1, segmentText: "blue lanterns", audioRange: 0..<2).wordIndex == 5)
    #expect(tracker.consume("glow", isFinal: false, hypothesisID: 2, segmentText: "glow", audioRange: 2..<3).wordIndex == 20)
}

@Test func adaptiveAccumulationDoesNotRelaxTheParagraphFence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Opening remarks establish clear context.\n\nFurther details support careful reading.\n\nQuantum sensors reveal unexpected magnetic patterns."))
    tracker.select(wordIndex: 0)
    for (index, word) in ["quantum", "sensors", "reveal", "unexpected", "magnetic", "patterns"].enumerated() {
        let update = tracker.consume(word, isFinal: true, hypothesisID: UInt64(index), segmentText: word,
                                     audioRange: Double(index)..<Double(index + 1))
        #expect(update.wordIndex == 0)
        #expect(update.evidence == nil)
        #expect(!update.isFinished)
    }
}

@Test func adaptiveFarRepeatedPhraseWaitsForDistinctiveContext() {
    let text = "Opening remarks explain our purpose clearly. Careful planning helps every participant understand all important practical constraints before proceeding. Blue lanterns glow today. Quiet rivers carry fresh water through this valley. Blue lanterns glow tomorrow."
    let document = ScriptDocument(text: text)
    var tracker = ScriptTracker(document: document)
    tracker.select(wordIndex: 5)
    #expect(tracker.consume("blue lanterns glow", isFinal: false, hypothesisID: 1, segmentText: "blue lanterns glow").wordIndex == 5)
    let update = tracker.consume("blue lanterns glow tomorrow", isFinal: false, hypothesisID: 1, segmentText: "blue lanterns glow tomorrow")
    #expect(update.wordIndex == document.words.count - 1)
    #expect(update.isMatched)
}

@Test func adaptiveManualSelectionClearsUnmatchedEvidence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    tracker.select(wordIndex: 5)
    _ = tracker.consume("blue", isFinal: false, hypothesisID: 1, segmentText: "blue", audioRange: 0..<1)
    _ = tracker.consume("lanterns", isFinal: false, hypothesisID: 2, segmentText: "lanterns", audioRange: 1..<2)
    tracker.select(wordIndex: 0)
    let update = tracker.consume("glow", isFinal: false, hypothesisID: 3, segmentText: "glow", audioRange: 2..<3)
    #expect(update.wordIndex == 0)
    #expect(!update.isMatched)
}

@Test func adaptiveExactContinuationCannotBypassBackwardSensitivity() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    #expect(tracker.consume("we can better", isFinal: false, hypothesisID: 1, segmentText: "we can better").wordIndex == 4)
    let revised = tracker.consume("create", isFinal: false, hypothesisID: 1, segmentText: "create")
    #expect(revised.wordIndex == 4)
    #expect(!revised.isMatched)
}

@Test func adaptiveLateKnownResultsDoNotDiscardNewerUnmatchedSpeech() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    let opening = "opening remarks explain our purpose clearly"
    #expect(tracker.consume(opening, isFinal: true, hypothesisID: 0, segmentText: opening, audioRange: 0..<1).wordIndex == 5)
    #expect(tracker.consume("blue", isFinal: false, hypothesisID: 1, segmentText: "blue", audioRange: 1..<2).wordIndex == 5)
    _ = tracker.consume(opening, isFinal: true, hypothesisID: 0, segmentText: opening, audioRange: 0..<1)
    #expect(tracker.consume("lanterns", isFinal: false, hypothesisID: 2, segmentText: "lanterns", audioRange: 2..<3).wordIndex == 5)
    #expect(tracker.consume("glow", isFinal: false, hypothesisID: 3, segmentText: "glow", audioRange: 3..<4).wordIndex == 20)
}

@Test func adaptiveOutOfOrderUnmatchedAudioKeepsItsSpokenOrder() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    tracker.select(wordIndex: 5)
    _ = tracker.consume("lanterns", isFinal: false, hypothesisID: 2, segmentText: "lanterns", audioRange: 1..<2)
    _ = tracker.consume("blue", isFinal: false, hypothesisID: 1, segmentText: "blue", audioRange: 0..<1)
    #expect(tracker.consume("glow", isFinal: false, hypothesisID: 3, segmentText: "glow", audioRange: 2..<3).wordIndex == 20)
}

@Test func adaptiveSensitivityTightensAsForwardDistanceGrows() {
    var previous = TrackingSensitivity(displacement: 0)
    for distance in 1...200 {
        let current = TrackingSensitivity(displacement: distance)
        #expect(current.minimumMatches >= previous.minimumMatches)
        #expect(current.minimumCoverage >= previous.minimumCoverage)
        #expect(current.ambiguityMargin >= previous.ambiguityMargin)
        previous = current
    }
}

@Test func adaptiveEarlierFinalCannotConfirmFutureProvisionalRecovery() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    tracker.select(wordIndex: 5)
    _ = tracker.consume("lanterns", isFinal: false, hypothesisID: 1, segmentText: "lanterns", audioRange: 1..<2)
    _ = tracker.consume("glow", isFinal: false, hypothesisID: 2, segmentText: "glow", audioRange: 2..<3)
    let earlier = tracker.consume("blue", isFinal: true, hypothesisID: 0, segmentText: "blue", audioRange: 0..<1)
    #expect(earlier.wordIndex == 5)
    #expect(earlier.confirmedWordIndex == 5)
    #expect(!earlier.isFinished)
    let latest = tracker.consume("glow", isFinal: false, hypothesisID: 2, segmentText: "glow", audioRange: 2..<3)
    #expect(latest.wordIndex == 20)
    #expect(latest.confirmedWordIndex == 5)
    #expect(!latest.isFinished)
    #expect(latest.evidence == nil)
}

@Test func adaptiveRecoveryUsesAFreshPhraseAfterEarlierUnmatchedChunks() {
    var tracker = ScriptTracker(document: ScriptDocument(text: adaptiveScript))
    tracker.select(wordIndex: 5)
    let words = ["random", "purple", "umbrellas", "blue", "lanterns", "glow"]
    for (index, word) in words.enumerated() {
        let update = tracker.consume(word, isFinal: false, hypothesisID: UInt64(index), segmentText: word,
                                     audioRange: Double(index)..<Double(index + 1))
        #expect(update.wordIndex == (index == words.count - 1 ? 20 : 5))
    }
}

@Test func adaptiveFreshPhraseOutweighsOneCoincidentalAdjacentWord() {
    let text = adaptiveScript.replacingOccurrences(of: "Blue lanterns glow.", with: "Blue lanterns careful.")
    var tracker = ScriptTracker(document: ScriptDocument(text: text))
    let opening = "opening remarks explain our purpose clearly"
    #expect(tracker.consume(opening, isFinal: true, hypothesisID: 0, segmentText: opening, audioRange: 0..<1).wordIndex == 5)
    _ = tracker.consume("blue", isFinal: false, hypothesisID: 1, segmentText: "blue", audioRange: 1..<2)
    _ = tracker.consume("lanterns", isFinal: false, hypothesisID: 2, segmentText: "lanterns", audioRange: 2..<3)
    let update = tracker.consume("careful", isFinal: false, hypothesisID: 3, segmentText: "careful", audioRange: 3..<4)
    #expect(update.wordIndex == 20)
    #expect(update.isMatched)
}
