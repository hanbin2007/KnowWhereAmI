import Testing
@testable import KnowWhereAmICore

@Test func followsEnglishWordsIgnoringCaseAndPunctuation() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Hello, everyone. Today we build something useful."))
    let update = tracker.consume("hello EVERYONE today we", isFinal: true)
    #expect(update.wordIndex == 3)
    #expect(update.confirmedWordIndex == 3)
    #expect(update.isMatched)
    #expect(!update.isFinished)
}

@Test func expandsContractionsWithoutLosingOriginalWordPositions() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "I'm certain we don't need another meeting today."))
    let update = tracker.consume("I am certain we do not need", isFinal: true)
    #expect(update.wordIndex == 4)
}

@Test func matchesSpelledOutNumbersToWrittenDigits() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We invited 42 people to this event."))
    let update = tracker.consume("we invited forty two people", isFinal: true)
    #expect(update.wordIndex == 3)
}

@Test func fillersAndOneMissedWordDoNotFreezeFollowing() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Today we will explore the beautiful northern coastline together."))
    let update = tracker.consume("um today we explore the uh northern coastline", isFinal: true)
    #expect(update.wordIndex == 7)
}

@Test func provisionalResultDoesNotCommitUntilFinalized() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    let tentative = tracker.consume("we can create a", isFinal: false)
    #expect(tentative.wordIndex == 3)
    #expect(tentative.confirmedWordIndex == nil)
    let final = tracker.consume("we can create a", isFinal: true)
    #expect(final.confirmedWordIndex == 3)
}

@Test func revisedPartialCanRetractButKeepConfirmedPosition() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    _ = tracker.consume("we can", isFinal: true)
    _ = tracker.consume("we can create a better", isFinal: false)
    let revised = tracker.consume("we can create", isFinal: false)
    #expect(revised.wordIndex == 2)
    #expect(revised.confirmedWordIndex == 1)
    let revoked = tracker.revokeTentative()
    #expect(revoked.wordIndex == 1)
}

@Test func unrelatedSpeechAndSilenceDoNotAdvance() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    _ = tracker.consume("we can create", isFinal: true)
    let unrelated = tracker.consume("please close your purple umbrella", isFinal: false)
    #expect(unrelated.wordIndex == 2)
    #expect(!unrelated.isMatched)
    #expect(tracker.consume("", isFinal: false).wordIndex == 2)
}

@Test func oldMatchingContextCannotHideNewOffScriptSpeech() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    _ = tracker.consume("we can create", isFinal: true)
    let update = tracker.consume("we can create purple umbrella banana", isFinal: false)
    #expect(update.wordIndex == 2)
    #expect(!update.isMatched)
}

@Test func repeatedPhraseChoosesNearbyOccurrenceNotLaterCopy() {
    let script = "Thank you for joining us. First we discuss the budget. Thank you for joining us. Now we discuss the future."
    var tracker = ScriptTracker(document: ScriptDocument(text: script))
    let first = tracker.consume("thank you for joining us", isFinal: true)
    #expect(first.wordIndex == 4)
    _ = tracker.consume("first we discuss the budget", isFinal: true)
    let second = tracker.consume("thank you for joining us", isFinal: true)
    #expect(second.wordIndex == 14)
}

@Test func supportsSkippingForwardAndRereadingWithinLocalWindow() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "First we review the plan. Next we discuss the budget. Finally we celebrate our progress."))
    #expect(tracker.consume("first we review the plan", isFinal: true).wordIndex == 4)
    #expect(tracker.consume("finally we celebrate our progress", isFinal: true).wordIndex == 14)
    #expect(tracker.consume("next we discuss the budget", isFinal: true).wordIndex == 9)
}

@Test func manualWordSelectionAllowsStartingAtChosenPosition() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "One small step can lead to a remarkable new beginning."))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("remarkable new beginning", isFinal: true).wordIndex == 9)
}

@Test func resetsPositionAndDoesNotInventSpeechForEmptyScript() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We make things better together."))
    _ = tracker.consume("we make things", isFinal: true)
    tracker.reset()
    #expect(tracker.consume("", isFinal: false).wordIndex == nil)
    var empty = ScriptTracker(document: ScriptDocument(text: " \n "))
    #expect(empty.consume("hello world", isFinal: true).wordIndex == nil)
}

@Test func reachingLastWordNeedsFinalEvidenceToFinish() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We make things better together."))
    #expect(!tracker.consume("we make things better together", isFinal: false).isFinished)
    #expect(tracker.consume("we make things better together", isFinal: true).isFinished)
}

@Test func uniqueLongPhraseCanRecoverFarOutsideLocalWindow() {
    let filler = Array(repeating: "ordinary background words fill this paragraph", count: 50).joined(separator: " ")
    var tracker = ScriptTracker(document: ScriptDocument(text: "Welcome to our opening remarks. \(filler) Quantum sensors reveal unexpected magnetic patterns today."))
    let result = tracker.consume("quantum sensors reveal unexpected magnetic patterns", isFinal: true)
    #expect(result.wordIndex == 310)
    #expect(result.isMatched)
}

@Test func identicalPartialAndFinalRevisionsDoNotConsumeRepeatedWords() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Go go go go now."))
    #expect(tracker.consume("go", isFinal: false).wordIndex == 0)
    #expect(tracker.consume("go", isFinal: false).wordIndex == 0)
    #expect(tracker.consume("Go!", isFinal: true).confirmedWordIndex == 0)
    #expect(tracker.consume("go", isFinal: true).wordIndex == 0)
}

@Test func expandingAndRetractingRepeatedWordHypothesisKeepsItsStart() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Go go go go now."))
    #expect(tracker.consume("go", isFinal: false).wordIndex == 0)
    #expect(tracker.consume("go go", isFinal: false).wordIndex == 1)
    #expect(tracker.consume("go", isFinal: false).wordIndex == 0)
    #expect(tracker.consume("go go", isFinal: true).wordIndex == 1)
}

@Test func nonmatchingReplacementRetractsUnevidencedTentativeCursor() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    _ = tracker.consume("we can", isFinal: true)
    _ = tracker.consume("we can create a better", isFinal: false)
    #expect(tracker.consume("purple umbrella banana", isFinal: false).wordIndex == 1)
    #expect(tracker.consume("purple umbrella banana", isFinal: true).confirmedWordIndex == 1)
}

@Test func offScriptExtensionKeepsPreviouslyEvidencedTentativeWords() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    _ = tracker.consume("we can", isFinal: true)
    _ = tracker.consume("we can create a better", isFinal: false)
    let update = tracker.consume("we can create a better purple umbrella banana", isFinal: false)
    #expect(update.wordIndex == 4)
    #expect(!update.isMatched)
}

@Test func cumulativeRepeatedSpeechContinuesBeyondMatchingWindow() {
    var tracker = ScriptTracker(document: ScriptDocument(text: Array(repeating: "Go", count: 45).joined(separator: " ")))
    for count in 1...40 {
        let text = Array(repeating: "go", count: count).joined(separator: " ")
        #expect(tracker.consume(text, isFinal: true).wordIndex == count - 1)
    }
}

@Test func thirdPersonContractionsAcceptIsAndHasExpansions() {
    for (script, spoken) in [("He's ready.", "he is ready"), ("She's finished.", "she has finished")] {
        var tracker = ScriptTracker(document: ScriptDocument(text: script))
        #expect(tracker.consume(spoken, isFinal: true).isFinished)
    }
}

@Test func distinctRepeatedAudioKeepsAdvancingAfterBufferRolls() {
    var tracker = ScriptTracker(document: ScriptDocument(text: Array(repeating: "Go", count: 45).joined(separator: " ")))
    var buffer = TranscriptBuffer()
    for index in 0..<40 {
        buffer.ingest(SpeechChunk(start: Double(index), end: Double(index + 1), text: "go", isFinal: true))
        let update = tracker.consume(buffer.text, isFinal: true, hypothesisID: buffer.hypothesisID)
        #expect(update.wordIndex == index)
    }
}

@Test func resumingDoesNotPromoteTentativeCursorToConfirmedEvidence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    _ = tracker.consume("we can", isFinal: true)
    _ = tracker.consume("we can create a better", isFinal: false)
    tracker.beginSession()
    let update = tracker.consume("purple umbrella banana", isFinal: false, hypothesisID: 0)
    #expect(update.confirmedWordIndex == 1)
}

@Test func startingAtManuallyChosenRepeatedWordDoesNotSkipIt() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Go go go go now."))
    tracker.select(wordIndex: 2)
    tracker.beginSession()
    #expect(tracker.consume("go", isFinal: false, hypothesisID: 0).wordIndex == 2)
}

@Test func multiwordAudioChunksAdvanceByNewSpeechAfterMatchingWindowRolls() {
    var tracker = ScriptTracker(document: ScriptDocument(text: Array(repeating: "Go", count: 100).joined(separator: " ")))
    var buffer = TranscriptBuffer()
    for index in 0..<20 {
        buffer.ingest(SpeechChunk(start: Double(index), end: Double(index + 1), text: "go go go", isFinal: true))
        let result = tracker.consume(buffer.text, isFinal: true, hypothesisID: buffer.hypothesisID, segmentText: "go go go")
        #expect(result.wordIndex == (index + 1) * 3 - 1)
    }
}

@Test func revisedStartOfOverlappingPartialDoesNotInventAnotherRepeatedWord() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Go go go now."))
    var buffer = TranscriptBuffer()
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "go", isFinal: false))
    #expect(tracker.consume(buffer.text, isFinal: false, hypothesisID: buffer.hypothesisID, segmentText: "go").wordIndex == 0)
    buffer.ingest(SpeechChunk(start: 0.02, end: 1, text: "go", isFinal: true))
    #expect(tracker.consume(buffer.text, isFinal: true, hypothesisID: buffer.hypothesisID, segmentText: "go").wordIndex == 0)
}

@Test func fillerOnlyReplacementRetractsTentativeWords() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    _ = tracker.consume("we can", isFinal: true)
    _ = tracker.consume("we can create a better", isFinal: false)
    #expect(tracker.consume("um", isFinal: true).wordIndex == 1)
}
