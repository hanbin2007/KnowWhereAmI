import Testing
@testable import KnowWhereAmICore

@Test func firstAndLastLinesCanOccupyTheFocusLane() {
    let insets = ReadingFocus.insets(viewportHeight: 500, lineHeight: 40, textInset: 12)
    #expect(insets.top >= 138)
    #expect(insets.bottom >= 298)
    let first = ReadingFocus.offset(lineMidY: 32, viewportHeight: 500, contentHeight: 1_040, topInset: insets.top, bottomInset: insets.bottom)
    let last = ReadingFocus.offset(lineMidY: 1_008, viewportHeight: 500, contentHeight: 1_040, topInset: insets.top, bottomInset: insets.bottom)
    #expect(abs((32 - first) - 170) < 0.01)
    #expect(abs((1_008 - last) - 170) < 0.01)
}

@Test func focusOffsetChangesWhenViewportHeightChangesWithoutNewSpeech() {
    let a = ReadingFocus.offset(lineMidY: 800, viewportHeight: 500, contentHeight: 2_000, topInset: 200, bottomInset: 400)
    let b = ReadingFocus.offset(lineMidY: 800, viewportHeight: 300, contentHeight: 2_000, topInset: 200, bottomInset: 400)
    #expect(abs(a - 630) < 0.01)
    #expect(abs(b - 698) < 0.01)
}

@Test func scrollingSpringMovesContinuouslyAndRetargetsWithoutJumping() {
    var spring = FocusSpring()
    spring.retarget(200)
    let first = spring.step(elapsed: 1.0 / 60)
    #expect(first > 0 && first < 200)
    let position = spring.position
    let velocity = spring.velocity
    spring.retarget(240)
    #expect(spring.position == position)
    #expect(spring.velocity == velocity)
    for _ in 0..<120 { spring.step(elapsed: 1.0 / 60) }
    #expect(abs(spring.position - 240) < 0.2)
    #expect(spring.isSettled)
}

@Test func displayRefreshRateDoesNotChangeSpringMotion() {
    var sixty = FocusSpring()
    var oneTwenty = FocusSpring()
    sixty.retarget(300)
    oneTwenty.retarget(300)
    for _ in 0..<30 { sixty.step(elapsed: 1.0 / 60) }
    for _ in 0..<60 { oneTwenty.step(elapsed: 1.0 / 120) }
    #expect(abs(sixty.position - oneTwenty.position) < 0.01)
    #expect(sixty.position > 299)
}

@Test func springHandlesLargePausesAndInvalidTimingWithoutNonfiniteOffsets() {
    var spring = FocusSpring(position: 40)
    spring.retarget(120)
    spring.step(elapsed: .nan)
    #expect(spring.position.isFinite)
    spring.step(elapsed: 5)
    #expect(abs(spring.position - 120) < 0.2)
    spring.jump(to: 10)
    #expect(spring.position == 10 && spring.velocity == 0 && spring.isSettled)
}
