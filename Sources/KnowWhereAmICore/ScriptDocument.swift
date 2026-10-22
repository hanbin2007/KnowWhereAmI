import Foundation

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

    public static func wordCount(in text: String) -> Int {
        EnglishNormalizer.wordExpression.numberOfMatches(in: text, range: NSRange(location: 0, length: text.utf16.count))
    }

    public init(text: String) {
        self.text = text
        let source = text as NSString
        let matches = EnglishNormalizer.wordExpression.matches(
            in: text, range: NSRange(location: 0, length: source.length)
        )
        self.words = matches.map { ScriptWord(text: source.substring(with: $0.range), range: $0.range) }
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
