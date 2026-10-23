import Testing
@testable import KnowWhereAmICore

private let boundedScript = """
Amber lanterns brighten quiet corridors. Patient readers notice subtle details. Careful speakers welcome thoughtful questions. Fresh notebooks capture useful insights.

Modern bridges connect distant communities. Quiet workshops encourage practical experiments. Clear diagrams explain complex systems. Honest feedback improves future decisions.

Steady practice builds lasting confidence. Focused teams deliver reliable results. Thoughtful planning prevents needless confusion. Shared knowledge supports better choices.

Curious students discover surprising connections. Simple routines preserve valuable attention. Precise language reduces hidden assumptions. Small improvements create meaningful progress.
"""

@Test func automaticBackwardJumpAcceptsTheThirdPreviousSentence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 47)
    let update = tracker.consume("clear diagrams explain complex systems", isFinal: true)
    #expect(update.isMatched)
    #expect(update.confirmedWordIndex == 34)
}

@Test func automaticBackwardJumpRejectsTheFourthPreviousSentence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 47)
    let update = tracker.consume("quiet workshops encourage practical experiments", isFinal: true)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 47)
    #expect(update.confirmedWordIndex == 47)
    #expect(update.evidence == nil)
}

@Test func automaticForwardJumpIncludesTheEndOfTheNextParagraph() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    let update = tracker.consume("honest feedback improves future decisions", isFinal: true)
    #expect(update.isMatched)
    #expect(update.confirmedWordIndex == 39)
}

@Test func automaticForwardJumpRejectsTheParagraphAfterNext() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    let update = tracker.consume("steady practice builds lasting confidence", isFinal: true)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 7)
    #expect(update.confirmedWordIndex == 7)
    #expect(update.evidence == nil)
}

@Test func strongGlobalRecoveryCannotSkipPastTheNextParagraph() {
    let filler = Array(repeating: "ordinary background words fill this paragraph", count: 50).joined(separator: " ")
    let script = "Welcome to our opening remarks.\n\n\(filler).\n\nQuantum sensors reveal unexpected magnetic patterns today."
    var tracker = ScriptTracker(document: ScriptDocument(text: script))
    let update = tracker.consume("quantum sensors reveal unexpected magnetic patterns", isFinal: true)
    #expect(!update.isMatched)
    #expect(update.wordIndex == nil)
    #expect(!update.isFinished)
    #expect(update.evidence == nil)
}

@Test func provisionalSpeechCanAdvanceTheWindowWithoutFinalizingCoverage() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false, hypothesisID: 0).wordIndex == 39)
    let update = tracker.consume("steady practice builds lasting confidence", isFinal: false, hypothesisID: 1)
    #expect(update.isMatched)
    #expect(update.confirmedWordIndex == 7)
    #expect(update.wordIndex == 44)
    #expect(update.evidence == nil)
}

@Test func cachedHypothesisCannotReturnBeyondTheCurrentBackwardLimit() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("clear diagrams explain complex systems", isFinal: true, hypothesisID: 0).wordIndex == 34)
    #expect(tracker.consume("shared knowledge supports better choices", isFinal: true, hypothesisID: 1).wordIndex == 59)
    #expect(tracker.consume("small improvements create meaningful progress", isFinal: true, hypothesisID: 2).wordIndex == 79)
    let update = tracker.consume("clear diagrams explain complex systems", isFinal: true, hypothesisID: 0)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 79)
    #expect(update.evidence == nil)
}

@Test func finalConfirmationAdvancesTheParagraphSearchWindow() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: true).wordIndex == 39)
    #expect(tracker.consume("shared knowledge supports better choices", isFinal: true).wordIndex == 59)
    #expect(tracker.consume("small improvements create meaningful progress", isFinal: true).isFinished)
}

@Test func manualSelectionCanReanchorOutsideTheAutomaticWindow() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 75)
    tracker.beginSession()
    #expect(tracker.consume("small improvements create meaningful progress", isFinal: true).wordIndex == 79)
    tracker.select(wordIndex: 0)
    #expect(tracker.consume("amber lanterns brighten quiet corridors", isFinal: true).wordIndex == 4)
}

@Test func aLongHypothesisCannotMoveItsPredictedAnchorPastTheForwardFence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    let update = tracker.consume(boundedScript, isFinal: true)
    #expect(!update.isMatched)
    #expect(update.wordIndex == nil)
    #expect(!update.isFinished)
}

@Test func globalBackwardRecoveryAlsoRespectsTheSentenceFence() {
    let filler = "Ordinary background words fill this paragraph "
        + Array(repeating: "ordinary background words fill this paragraph", count: 59).joined(separator: " ")
    let text = "Quantum sensors reveal unexpected magnetic patterns today. "
        + Array(repeating: filler + ".", count: 6).joined(separator: " ")
        + " Current readers compare practical options."
    let document = ScriptDocument(text: text)
    let anchor = document.words.count - 2
    var tracker = ScriptTracker(document: document)
    tracker.select(wordIndex: anchor)
    let update = tracker.consume("quantum sensors reveal unexpected magnetic patterns", isFinal: true)
    #expect(!update.isMatched)
    #expect(update.wordIndex == anchor)
    #expect(update.evidence == nil)
}

@Test func abbreviationsDoNotConsumeAnExtraSentenceOfBackwardReach() {
    let document = ScriptDocument(text: "A calm opening sets direction. Dr. Ada reviews each proposal. The second review checks assumptions. Fresh evidence supports careful choices. Current readers compare practical options.")
    #expect(document.trackingWordRange(around: 22) == 5..<25)
}

@Test func paragraphFenceHandlesCRLFBlankLinesAndQuotedSentences() {
    let document = ScriptDocument(text: "Opening remarks establish clear context.\r\n\r\n\"Quoted statements stay inside paragraphs.\" Further details support careful reading.\r\n\r\nLater sections introduce separate material.")
    #expect(document.trackingWordRange(around: 2) == 0..<15)
    var tracker = ScriptTracker(document: document)
    tracker.select(wordIndex: 2)
    #expect(tracker.consume("later sections introduce separate material", isFinal: true).wordIndex == 2)
    #expect(tracker.consume("further details support careful reading", isFinal: true).wordIndex == 14)
}

@Test func resetRestoresTheInitialParagraphFence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 75)
    tracker.reset()
    let update = tracker.consume("small improvements create meaningful progress", isFinal: true)
    #expect(!update.isMatched)
    #expect(update.wordIndex == nil)
}

@Test func explicitResumeCanStartAtTheNextParagraphWithoutPromotingTentativeEvidence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    #expect(tracker.consume("fresh notebooks capture useful insights", isFinal: true).wordIndex == 19)
    tracker.beginSession()
    #expect(tracker.consume("modern bridges connect distant communities", isFinal: false).wordIndex == 24)
    #expect(tracker.consume("shared knowledge supports better choices", isFinal: false).wordIndex == 59)
    #expect(tracker.confirmedWordIndex == 19)
}

@Test func provisionalProgressCannotPermitASixSentenceVisibleBackwardJump() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false, hypothesisID: 0).wordIndex == 39)
    let update = tracker.consume("patient readers notice subtle details", isFinal: true, hypothesisID: 1)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 39)
    #expect(update.confirmedWordIndex == 7)
    #expect(update.evidence == nil)
}

@Test func provisionalRereadingCannotPermitATwoParagraphVisibleForwardJump() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 47)
    #expect(tracker.consume("clear diagrams explain complex systems", isFinal: false, hypothesisID: 0).wordIndex == 34)
    let update = tracker.consume("small improvements create meaningful progress", isFinal: true, hypothesisID: 1)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 34)
    #expect(update.confirmedWordIndex == 47)
    #expect(update.evidence == nil)
}

@Test func revokingADistantTentativePositionDoesNotSnapBackPastThreeSentences() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false).wordIndex == 39)
    let update = tracker.revokeTentative()
    #expect(!update.isMatched)
    #expect(update.wordIndex == 39)
    #expect(update.confirmedWordIndex == 7)
}

@Test func anEarlierPendingFinalCanBeScoredWithoutRewindingTheDisplayedCursor() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("patient readers notice subtle details", isFinal: false, hypothesisID: 0).wordIndex == 9)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false, hypothesisID: 1).wordIndex == 39)
    let update = tracker.consume("patient readers notice subtle details", isFinal: true, hypothesisID: 0)
    #expect(update.wordIndex == 39)
    #expect(update.confirmedWordIndex == 9)
    #expect(update.evidence?.matchedWordIndices == Set(5...9))
}

@Test func revocationWithoutConfirmedSpeechCannotJumpBackToTheScriptBeginning() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false).wordIndex == 39)
    let update = tracker.revokeTentative()
    #expect(update.wordIndex == 39)
    #expect(update.confirmedWordIndex == nil)
    #expect(!update.isMatched)
}

@Test func aRevisedPendingFinalRetainsCoverageWithoutMovingTheDisplayedCursor() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    var buffer = TranscriptBuffer()
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "patient readers notice subtle details", isFinal: false))
    #expect(tracker.consume(buffer.text, isFinal: false, hypothesisID: buffer.hypothesisID, segmentText: buffer.segmentText).wordIndex == 9)
    buffer.ingest(SpeechChunk(start: 1, end: 2, text: "honest feedback improves future decisions", isFinal: false))
    #expect(tracker.consume(buffer.text, isFinal: false, hypothesisID: buffer.hypothesisID, segmentText: buffer.segmentText).wordIndex == 39)
    buffer.ingest(SpeechChunk(start: 0, end: 1, text: "patient readers notice useful details", isFinal: true))
    let update = tracker.consume(buffer.finalizedText, isFinal: true,
                                 hypothesisID: buffer.finalizedHypothesisID, segmentText: buffer.finalizedSegmentText)
    #expect(update.wordIndex == 39)
    #expect(update.confirmedWordIndex == 9)
    #expect(update.evidence?.matchedWordIndices == Set([5, 6, 7, 9]))
    #expect(update.evidence?.assessedWordIndices == Set(5...9))
}

@Test(arguments: ["patient readers notice subtle", "patient readers notice subtle details careful speakers"])
func aPendingFinalCanReviseItsEndpointWithoutMovingTheDisplayedCursor(finalText: String) {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("patient readers notice subtle details", isFinal: false, hypothesisID: 0).wordIndex == 9)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false, hypothesisID: 1).wordIndex == 39)
    let update = tracker.consume(finalText, isFinal: true, hypothesisID: 0)
    let finalEnd = finalText.split(separator: " ").count + 4
    #expect(update.wordIndex == 39)
    #expect(update.confirmedWordIndex == finalEnd)
    #expect(update.evidence?.matchedWordIndices == Set(5...finalEnd))
    #expect(update.evidence?.assessedWordIndices == Set(5...finalEnd))
}

@Test func aPendingFinalCannotResolveBeyondItsOriginalForwardFence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("patient readers notice subtle details", isFinal: false, hypothesisID: 0).wordIndex == 9)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false, hypothesisID: 1).wordIndex == 39)
    let rejected = tracker.consume("steady practice builds lasting confidence", isFinal: true, hypothesisID: 0)
    #expect(!rejected.isMatched)
    #expect(rejected.wordIndex == 39)
    #expect(rejected.confirmedWordIndex == 7)
    #expect(rejected.evidence == nil)
    let corrected = tracker.consume("patient readers notice subtle", isFinal: true, hypothesisID: 0)
    #expect(corrected.wordIndex == 39)
    #expect(corrected.confirmedWordIndex == 8)
    #expect(corrected.evidence?.matchedWordIndices == Set(5...8))
}

@Test func aPendingFinalCannotResolveBeyondItsOriginalBackwardFence() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 47)
    #expect(tracker.consume("clear diagrams explain complex systems", isFinal: false, hypothesisID: 0).wordIndex == 34)
    #expect(tracker.consume("shared knowledge supports better choices", isFinal: false, hypothesisID: 1).wordIndex == 59)
    let update = tracker.consume("quiet workshops encourage practical experiments", isFinal: true, hypothesisID: 0)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 59)
    #expect(update.confirmedWordIndex == 47)
    #expect(update.evidence == nil)
}

@Test func aPendingFinalPreservesFullSegmentCoverageBeforeItsBoundedEndpoint() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 47)
    #expect(tracker.consume("clear diagrams explain complex systems", isFinal: false, hypothesisID: 0).wordIndex == 34)
    #expect(tracker.consume("shared knowledge supports better choices", isFinal: false, hypothesisID: 1).wordIndex == 59)
    let update = tracker.consume("quiet workshops encourage practical experiments clear diagrams explain complex systems",
                                 isFinal: true, hypothesisID: 0)
    #expect(update.wordIndex == 59)
    #expect(update.confirmedWordIndex == 34)
    #expect(update.evidence?.matchedWordIndices == Set(25...34))
    #expect(update.evidence?.assessedWordIndices == Set(25...34))
}

@Test func streamingContinuousPartialCanReadAcrossEveryParagraphBeforeFinalization() {
    let document = ScriptDocument(text: boundedScript)
    var tracker = ScriptTracker(document: document)
    tracker.beginSession()
    for count in 1...document.words.count {
        let text = document.words.prefix(count).map(\.text).joined(separator: " ")
        let update = tracker.consume(text, isFinal: false, hypothesisID: 0, segmentText: text)
        #expect(update.wordIndex == count - 1)
        #expect(update.confirmedWordIndex == nil)
        #expect(!update.isFinished)
    }
}

@Test func streamingDistinctAudioSegmentsCanKeepReadingWithoutFinalResults() {
    let document = ScriptDocument(text: boundedScript)
    var tracker = ScriptTracker(document: document)
    var buffer = TranscriptBuffer()
    for start in stride(from: 0, to: document.words.count, by: 5) {
        let text = document.words[start..<(start + 5)].map(\.text).joined(separator: " ")
        buffer.ingest(SpeechChunk(start: Double(start), end: Double(start + 5), text: text, isFinal: false))
        let update = tracker.consume(buffer.text, isFinal: false, hypothesisID: buffer.hypothesisID, segmentText: buffer.segmentText)
        #expect(update.wordIndex == start + 4)
        #expect(update.confirmedWordIndex == nil)
    }
}

@Test func streamingOneNewWordCannotBorrowOldContextToJustifyADistantJump() {
    let document = ScriptDocument(text: "Opening remarks explain our purpose clearly. We build futures together.")
    var tracker = ScriptTracker(document: document)
    var buffer = TranscriptBuffer()
    buffer.ingest(SpeechChunk(start: 0, end: 2, text: "opening remarks explain our purpose clearly", isFinal: true))
    #expect(tracker.consume(buffer.text, isFinal: true, hypothesisID: buffer.hypothesisID, segmentText: buffer.segmentText).wordIndex == 5)
    buffer.ingest(SpeechChunk(start: 2, end: 3, text: "together", isFinal: false))
    let update = tracker.consume(buffer.text, isFinal: false, hypothesisID: buffer.hypothesisID, segmentText: buffer.segmentText)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 5)
}

@Test func streamingUnmatchedRevisionDoesNotSnapToAnOldFinalPosition() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    #expect(tracker.consume("we can", isFinal: true, hypothesisID: 0).wordIndex == 1)
    #expect(tracker.consume("create a better", isFinal: false, hypothesisID: 1).wordIndex == 4)
    let update = tracker.consume("creative purple weather", isFinal: false, hypothesisID: 1)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 4)
    #expect(update.confirmedWordIndex == 1)
}

@Test func streamingAnEarlierFinalScoresWithoutRewindingNewerNearbyAudio() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    #expect(tracker.consume("amber lanterns brighten quiet corridors", isFinal: false, hypothesisID: 0).wordIndex == 4)
    #expect(tracker.consume("patient readers notice subtle details", isFinal: false, hypothesisID: 1).wordIndex == 9)
    let update = tracker.consume("amber lanterns brighten quiet corridors", isFinal: true, hypothesisID: 0)
    #expect(update.wordIndex == 9)
    #expect(update.confirmedWordIndex == 4)
    #expect(update.evidence?.matchedWordIndices == Set(0...4))
}

@Test func streamingAShortNewSegmentCannotPullTheCursorBackward() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We review the detailed plan before discussing reliable alternatives."))
    #expect(tracker.consume("we review the detailed plan", isFinal: true, hypothesisID: 0).wordIndex == 4)
    let update = tracker.consume("the", isFinal: false, hypothesisID: 1, segmentText: "the")
    #expect(!update.isMatched)
    #expect(update.wordIndex == 4)
}

@Test func streamingMostlyOffScriptNewSegmentCannotJumpOnThreeTrailingWords() {
    let text = "Opening remarks explain our purpose clearly. A careful discussion brings useful context before the team considers several practical choices and compares their likely effects. We can improve."
    var tracker = ScriptTracker(document: ScriptDocument(text: text))
    #expect(tracker.consume("opening remarks explain our purpose clearly", isFinal: true, hypothesisID: 0).wordIndex == 5)
    let spoken = "purple umbrellas cover yesterday's unexpected thunderstorm while strangers wonder whether we can improve"
    let update = tracker.consume(spoken, isFinal: false, hypothesisID: 1, segmentText: spoken)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 5)
}

@Test func streamingAnAcceptedPrefixCannotAuthorizeANoisyRevisionJump() {
    let text = "Opening remarks explain our purpose clearly. A careful discussion brings useful context before the team considers several practical choices and compares their likely effects. We can improve."
    var tracker = ScriptTracker(document: ScriptDocument(text: text))
    #expect(tracker.consume("opening remarks explain our purpose clearly", isFinal: true, hypothesisID: 0).wordIndex == 5)
    #expect(tracker.consume("a careful", isFinal: false, hypothesisID: 1, segmentText: "a careful").wordIndex == 7)
    let spoken = "a careful purple umbrellas cover yesterday's unexpected thunderstorm while strangers wonder whether we can improve"
    let update = tracker.consume(spoken, isFinal: false, hypothesisID: 1, segmentText: spoken)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 7)
}

@Test func streamingOneNewWordInAGrowingPartialCannotAuthorizeADistantJump() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Opening remarks explain our purpose clearly. We can build a better future together."))
    let first = "opening remarks explain our purpose clearly"
    #expect(tracker.consume(first, isFinal: false, hypothesisID: 0, segmentText: first).wordIndex == 5)
    let next = first + " together"
    let update = tracker.consume(next, isFinal: false, hypothesisID: 0, segmentText: next)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 5)
}

@Test func streamingLateFinalCannotOverwriteNewerBackwardReadingConfirmation() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "First we review the plan. Next we discuss the budget. Finally we celebrate our progress."))
    #expect(tracker.consume("finally we celebrate our progress", isFinal: false, hypothesisID: 0).wordIndex == 14)
    #expect(tracker.consume("next we discuss the budget", isFinal: true, hypothesisID: 1).wordIndex == 9)
    let late = tracker.consume("finally we celebrate our progress", isFinal: true, hypothesisID: 0)
    #expect(late.wordIndex == 9)
    #expect(late.confirmedWordIndex == 9)
    #expect(late.evidence?.matchedWordIndices == Set(10...14))
    #expect(tracker.revokeTentative().wordIndex == 9)
}

@Test func streamingThreeNewWordsCanJumpAcrossASkippedSentenceInOneHypothesis() {
    let text = "Opening remarks explain our purpose clearly. Careful planning helps every participant understand all important practical constraints before proceeding. Blue lanterns glow."
    var tracker = ScriptTracker(document: ScriptDocument(text: text))
    let opening = "opening remarks explain our purpose clearly"
    #expect(tracker.consume(opening, isFinal: false, hypothesisID: 0, segmentText: opening).wordIndex == 5)
    #expect(tracker.consume(opening + " blue", isFinal: false, hypothesisID: 0, segmentText: opening + " blue").wordIndex == 5)
    #expect(tracker.consume(opening + " blue lanterns", isFinal: false, hypothesisID: 0, segmentText: opening + " blue lanterns").wordIndex == 5)
    let spoken = opening + " blue lanterns glow"
    let update = tracker.consume(spoken, isFinal: false, hypothesisID: 0, segmentText: spoken)
    #expect(update.wordIndex == 20)
    #expect(update.isMatched)
    #expect(update.confirmedWordIndex == nil)
}

@Test func streamingShortExactPhraseCanRereadTwoLongSentencesBack() {
    let middle = "Careful planning helps every participant understand the practical constraints before proceeding with a proposal that includes several connected ideas about useful experiments and their expected outcomes while leaving enough time for questions from colleagues who bring different experiences and perspectives to this important discussion."
    let document = ScriptDocument(text: "Quartz sensors stabilize. \(middle) Current readers compare practical options.")
    var tracker = ScriptTracker(document: document)
    tracker.select(wordIndex: document.words.count - 2)
    let update = tracker.consume("quartz sensors stabilize", isFinal: false, hypothesisID: 0, segmentText: "quartz sensors stabilize")
    #expect(update.wordIndex == 2)
    #expect(update.isMatched)
}

@Test func streamingMergedAudioRangesUseTheirEndTimeRatherThanIdentityOrder() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    var buffer = TranscriptBuffer()
    let chunks = [
        SpeechChunk(start: 0, end: 1, text: "we can", isFinal: false),
        SpeechChunk(start: 1, end: 2, text: "create a", isFinal: false),
        SpeechChunk(start: 0, end: 3, text: "we can create a better future", isFinal: false),
        SpeechChunk(start: 0, end: 3, text: "we can create a better future", isFinal: true)
    ]
    for (chunk, expected) in zip(chunks, [1, 3, 5, 5]) {
        buffer.ingest(chunk)
        let update = tracker.consume(buffer.text, isFinal: chunk.isFinal, hypothesisID: buffer.hypothesisID,
                                     segmentText: buffer.segmentText, audioRange: buffer.segmentAudioRange)
        #expect(update.wordIndex == expected)
    }
    #expect(tracker.confirmedWordIndex == 5)
}

@Test func streamingEarlierAudioPrefixDoesNotRevokeLaterMatchedAudio() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    #expect(tracker.consume("we can create a better future", isFinal: false, hypothesisID: 0,
                            segmentText: "we can create a better future", audioRange: 0..<3).wordIndex == 5)
    let prefix = tracker.consume("we can create a better", isFinal: true, hypothesisID: 0,
                                 segmentText: "we can create a better", audioRange: 0..<2)
    #expect(prefix.wordIndex == 5)
    #expect(prefix.confirmedWordIndex == 4)
}

@Test func streamingCorrectionOfTheActiveAudioRangeCanRetractAMisrecognizedWord() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "We can create a better future together."))
    #expect(tracker.consume("we can create a better future", isFinal: false, hypothesisID: 0,
                            segmentText: "we can create a better future", audioRange: 0..<3).wordIndex == 5)
    let corrected = tracker.consume("we can create a better", isFinal: true, hypothesisID: 0,
                                    segmentText: "we can create a better", audioRange: 0..<3)
    #expect(corrected.wordIndex == 4)
    #expect(corrected.confirmedWordIndex == 4)
}

@Test(arguments: [false, true])
func streamingAcceptedShortJumpKeepsItsFinalEvidenceWhenNewerAudioArrives(firstReceiveNewerAudio: Bool) {
    let text = "Opening remarks explain our purpose clearly. Careful planning helps every participant understand all important practical constraints before proceeding. Blue lanterns glow. Small rivers flow."
    var tracker = ScriptTracker(document: ScriptDocument(text: text))
    let opening = "opening remarks explain our purpose clearly"
    #expect(tracker.consume(opening, isFinal: false, hypothesisID: 0, segmentText: opening).wordIndex == 5)
    let jumped = opening + " blue lanterns glow"
    #expect(tracker.consume(jumped, isFinal: false, hypothesisID: 0, segmentText: jumped).wordIndex == 20)
    if firstReceiveNewerAudio {
        #expect(tracker.consume("small rivers flow", isFinal: false, hypothesisID: 1, segmentText: "small rivers flow").wordIndex == 23)
    }
    let final = tracker.consume(jumped, isFinal: true, hypothesisID: 0, segmentText: jumped)
    #expect(final.wordIndex == (firstReceiveNewerAudio ? 23 : 20))
    #expect(final.confirmedWordIndex == 20)
    #expect(final.evidence?.matchedWordIndices.isSuperset(of: Set(18...20)) == true)
}

@Test(arguments: [false, true])
func streamingANoisySameLengthFinalCannotBorrowAcceptedConfidence(firstReceiveNewerAudio: Bool) {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Opening remarks explain our purpose clearly. We can improve. Small rivers flow."))
    #expect(tracker.consume("opening remarks explain our purpose", isFinal: false, hypothesisID: 0).wordIndex == 4)
    #expect(tracker.consume("opening remarks explain our purpose clearly", isFinal: false, hypothesisID: 0).wordIndex == 5)
    if firstReceiveNewerAudio {
        #expect(tracker.consume("small rivers flow", isFinal: false, hypothesisID: 1).wordIndex == 11)
    }
    let final = tracker.consume("purple umbrellas thunderstorms we can improve", isFinal: true, hypothesisID: 0)
    #expect(final.wordIndex == (firstReceiveNewerAudio ? 11 : 5))
    #expect(final.confirmedWordIndex == nil)
    #expect(final.evidence == nil)
}

@Test func streamingOneReplacedWordCannotAuthorizeADistantJump() {
    var tracker = ScriptTracker(document: ScriptDocument(text: "Opening remarks explain our purpose clearly. We can build a better future together."))
    #expect(tracker.consume("opening remarks explain our purpose clearly", isFinal: false, hypothesisID: 0).wordIndex == 5)
    let update = tracker.consume("opening remarks explain our purpose together", isFinal: false, hypothesisID: 0)
    #expect(!update.isMatched)
    #expect(update.wordIndex == 5)
}

@Test func streamingOneUncertainASRWordDoesNotFreezeAnOtherwiseMatchedRevision() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    #expect(tracker.consume("patient readers notice subtle details", isFinal: false, hypothesisID: 0).wordIndex == 9)
    let corrected = tracker.consume("patient readers notice useful details", isFinal: true, hypothesisID: 0)
    #expect(corrected.wordIndex == 9)
    #expect(corrected.confirmedWordIndex == 9)
    #expect(corrected.evidence?.matchedWordIndices == Set([5, 6, 7, 9]))
}
