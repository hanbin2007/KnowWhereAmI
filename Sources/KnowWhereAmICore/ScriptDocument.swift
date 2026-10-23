import Foundation
import NaturalLanguage

public struct ScriptWord: Equatable, Sendable {
    public let text: String
    public let range: NSRange
}

public struct ScriptDocument: Sendable {
    public let text: String
    public let words: [ScriptWord]
    let units: [MatchingUnit]
    let wordUnitStarts: [Int]
    let positions: [String: [Int]]
    private let sentenceStarts: [Int]
    private let paragraphStarts: [Int]

    public static func wordCount(in text: String) -> Int {
        EnglishNormalizer.wordExpression.numberOfMatches(in: text, range: NSRange(location: 0, length: text.utf16.count))
    }

    public init(text: String) {
        self.text = text
        let source = text as NSString
        let matches = EnglishNormalizer.wordExpression.matches(
            in: text, range: NSRange(location: 0, length: source.length)
        )
        let words = matches.map { ScriptWord(text: source.substring(with: $0.range), range: $0.range) }
        self.words = words
        var units: [MatchingUnit] = []
        var starts: [Int] = []
        var positions: [String: [Int]] = [:]
        for (index, word) in words.enumerated() {
            starts.append(units.count)
            for normalized in EnglishNormalizer.units(for: word.text) {
                positions[normalized, default: []].append(units.count)
                units.append(MatchingUnit(text: normalized, wordIndex: index))
            }
        }
        self.units = units
        self.wordUnitStarts = starts
        self.positions = positions
        sentenceStarts = Self.sectionStarts(in: text, words: words, unit: .sentence)
        paragraphStarts = Self.sectionStarts(in: text, words: words, unit: .paragraph)
    }

    func trackingWordRange(around word: Int) -> Range<Int> {
        guard !words.isEmpty else { return 0..<0 }
        let anchor = min(words.count - 1, max(0, word))
        let sentence = Self.sectionIndex(in: sentenceStarts, at: anchor)
        let paragraph = Self.sectionIndex(in: paragraphStarts, at: anchor)
        let lower = sentenceStarts[max(0, sentence - 3)]
        let upper = paragraph + 2 < paragraphStarts.count ? paragraphStarts[paragraph + 2] : words.count
        return lower..<upper
    }

    private static func sectionStarts(in text: String, words: [ScriptWord], unit: NLTokenUnit) -> [Int] {
        guard !words.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text
        tokenizer.setLanguage(.english)
        var starts: [Int] = []
        var word = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let span = NSRange(range, in: text)
            while word < words.count, words[word].range.location < span.location { word += 1 }
            if word < words.count, words[word].range.location < NSMaxRange(span), starts.last != word {
                starts.append(word)
            }
            return true
        }
        if starts.first != 0 { starts.insert(0, at: 0) }
        return starts
    }

    private static func sectionIndex(in starts: [Int], at word: Int) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= word { low = middle + 1 } else { high = middle }
        }
        return max(0, low - 1)
    }

    public func wordIndex(atUTF16Offset offset: Int) -> Int? {
        guard offset >= 0 else { return nil }
        var low = 0
        var high = words.count
        while low < high {
            let middle = (low + high) / 2
            let range = words[middle].range
            if offset < range.location {
                high = middle
            } else if offset >= NSMaxRange(range) {
                low = middle + 1
            } else {
                return middle
            }
        }
        return nil
    }
}

struct MatchingUnit: Sendable {
    let text: String
    let wordIndex: Int
}
