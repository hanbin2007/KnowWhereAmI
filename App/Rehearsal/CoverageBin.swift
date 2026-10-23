import Foundation

/// Proportional manuscript slices for the coverage map.
struct CoverageBin: Equatable {
    let matched: Int
    let missed: Int
    let total: Int
    var unassessed: Int { total - matched - missed }

    static func make(wordCount: Int, matched: [Int], missed: [Int], maximumBins: Int = 240) -> [CoverageBin] {
        guard wordCount > 0 else { return [] }
        let matchedSet = Set(matched.filter { (0..<wordCount).contains($0) })
        let missedSet = Set(missed.filter { (0..<wordCount).contains($0) }).subtracting(matchedSet)
        // Equal full-tile area represents equal word counts; only the final tile can be partial.
        let wordsPerBin = (wordCount - 1) / max(1, maximumBins) + 1
        return stride(from: 0, to: wordCount, by: wordsPerBin).map { start in
            let end = start + min(wordsPerBin, wordCount - start)
            var matched = 0
            var missed = 0
            for index in start..<end {
                if matchedSet.contains(index) { matched += 1 }
                else if missedSet.contains(index) { missed += 1 }
            }
            return CoverageBin(matched: matched, missed: missed, total: end - start)
        }
    }
}
