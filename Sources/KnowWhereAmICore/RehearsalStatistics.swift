import Foundation

public struct RehearsalStatistics: Codable, Equatable, Sendable {
    public let elapsedSeconds: Double
    public let spokenWords: Int
    public let wordsPerMinute: Double?
    public let matchedWords: Int
    public let missedWords: Int
    public let assessedWords: Int
    public let unassessedWords: Int
    /// Estimated manuscript coverage from final ASR text, not pronunciation quality.
    public let accuracy: Double?
    public let omittedWordIndices: [Int]
    public let matchedWordIndices: [Int]
    public let assessedWordIndices: [Int]
}

public struct RehearsalAccumulator: Sendable {
    private let wordCount: Int
    private var spokenWords = 0
    private var matchedWords: Set<Int> = []
    private var assessedWords: Set<Int> = []
    private var lastSupportedEnd: Int?

    public init(document: ScriptDocument, startWord: Int = 0) {
        wordCount = document.words.count
        setAnchor(wordIndex: startWord)
    }

    public mutating func recordFinal(text: String, evidence: AlignmentEvidence?) {
        let count = ScriptDocument.wordCount(in: text)
        guard count > 0 else { return }
        spokenWords += count
        guard let evidence else {
            lastSupportedEnd = nil
            return
        }
        let matched = evidence.matchedWordIndices.filter { (0..<wordCount).contains($0) }
        guard let first = matched.min(), let last = matched.max() else {
            lastSupportedEnd = nil
            return
        }
        let assessed = evidence.assessedWordIndices.filter { (0..<wordCount).contains($0) }
        // Only speech at both ends supports an estimated skipped gap. A manual
        // anchor or an unaligned result breaks that inference.
        if let previous = lastSupportedEnd, previous + 1 < first {
            assessedWords.formUnion((previous + 1)..<first)
        }
        matchedWords.formUnion(matched)
        assessedWords.formUnion(assessed)
        assessedWords.formUnion(matched)
        lastSupportedEnd = last
    }

    public mutating func setAnchor(wordIndex: Int) {
        guard (0..<wordCount).contains(wordIndex) || wordCount == 0 else { return }
        lastSupportedEnd = nil
    }

    public func snapshot(elapsedSeconds: Double) -> RehearsalStatistics {
        let elapsed = elapsedSeconds.isFinite ? max(0, elapsedSeconds) : 0
        let rate = elapsed > 0 && spokenWords > 0 ? Double(spokenWords) / elapsed * 60 : nil
        let omitted = assessedWords.subtracting(matchedWords)
        return RehearsalStatistics(
            elapsedSeconds: elapsed,
            spokenWords: spokenWords,
            wordsPerMinute: rate?.isFinite == true ? rate : nil,
            matchedWords: matchedWords.count,
            missedWords: omitted.count,
            assessedWords: assessedWords.count,
            unassessedWords: max(0, wordCount - assessedWords.count),
            accuracy: assessedWords.isEmpty ? nil : Double(matchedWords.count) / Double(assessedWords.count),
            omittedWordIndices: omitted.sorted(),
            matchedWordIndices: matchedWords.sorted(),
            assessedWordIndices: assessedWords.sorted()
        )
    }
}
