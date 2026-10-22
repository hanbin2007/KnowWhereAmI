import XCTest
@testable import KnowWhereAmI

final class RehearsalChartTests: XCTestCase {
    func testLongManuscriptBucketsPreserveAllActualCounts() {
        let bins = CoverageBin.make(wordCount: 10_003, matched: Array(0..<1_234), missed: [1_234, 7_777, 10_002])
        XCTAssertLessThanOrEqual(bins.count, 240)
        XCTAssertTrue(bins.dropLast().allSatisfy { $0.total == 42 })
        XCTAssertEqual(bins.last?.total, 7)
        XCTAssertEqual(bins.reduce(0) { $0 + $1.total }, 10_003)
        XCTAssertEqual(bins.reduce(0) { $0 + $1.matched }, 1_234)
        XCTAssertEqual(bins.reduce(0) { $0 + $1.missed }, 3)
        XCTAssertEqual(bins.reduce(0) { $0 + $1.unassessed }, 8_766)
    }

    func testShortManuscriptKeepsEachWordAndIgnoresInvalidDuplicateIndices() {
        let bins = CoverageBin.make(wordCount: 4, matched: [0, 0, 1, -1, 9], missed: [1, 2, 2, -2, 4])
        XCTAssertEqual(bins, [CoverageBin(matched: 1, missed: 0, total: 1),
                              CoverageBin(matched: 1, missed: 0, total: 1),
                              CoverageBin(matched: 0, missed: 1, total: 1),
                              CoverageBin(matched: 0, missed: 0, total: 1)])
    }

    func testEmptyAndZeroBinRequestsCannotDivideByZero() {
        XCTAssertTrue(CoverageBin.make(wordCount: 0, matched: [], missed: []).isEmpty)
        XCTAssertEqual(CoverageBin.make(wordCount: 3, matched: [], missed: [], maximumBins: 0),
                       [CoverageBin(matched: 0, missed: 0, total: 3)])
    }

    func testEveryFullTileRepresentsTheSameNumberOfWords() {
        let bins = CoverageBin.make(wordCount: 360, matched: Array(stride(from: 0, to: 360, by: 3)), missed: [])
        XCTAssertEqual(bins.count, 180)
        XCTAssertTrue(bins.allSatisfy { $0.total == 2 }, "Equal tile area must represent equal word counts")
        let matchedArea = bins.reduce(0.0) { $0 + Double($1.matched) / Double($1.total) }
        XCTAssertEqual(matchedArea / Double(bins.count), 1.0 / 3.0, accuracy: 0.0001)
    }
}
