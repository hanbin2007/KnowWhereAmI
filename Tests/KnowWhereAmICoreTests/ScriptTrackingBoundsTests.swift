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

@Test func provisionalUpdatesCannotWalkTheForwardLimitAcrossParagraphs() {
    var tracker = ScriptTracker(document: ScriptDocument(text: boundedScript))
    tracker.select(wordIndex: 7)
    #expect(tracker.consume("honest feedback improves future decisions", isFinal: false, hypothesisID: 0).wordIndex == 39)
    let update = tracker.consume("steady practice builds lasting confidence", isFinal: false, hypothesisID: 1)
    #expect(!update.isMatched)
    #expect(update.confirmedWordIndex == 7)
    #expect(update.wordIndex != 44)
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
    #expect(update.wordIndex == 47)
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
    #expect(update.wordIndex == 47)
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
    #expect(update.confirmedWordIndex == 47)
    #expect(update.evidence?.matchedWordIndices == Set(25...34))
    #expect(update.evidence?.assessedWordIndices == Set(25...34))
}
