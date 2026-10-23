import Foundation

/// Spoken-pace bands. Descriptive only; there is no "correct" rate.
enum PaceBand {
    case unhurried, conversational, brisk
    static let comfortable = 115.0...165.0

    init(wordsPerMinute: Double) {
        if wordsPerMinute < Self.comfortable.lowerBound { self = .unhurried }
        else if wordsPerMinute <= Self.comfortable.upperBound { self = .conversational }
        else { self = .brisk }
    }

    var title: String {
        switch self {
        case .unhurried: "Unhurried"
        case .conversational: "Conversational"
        case .brisk: "Brisk"
        }
    }
}

enum ReadingLength {
    /// Minutes to read aloud at a conversational 140 words per minute.
    static func minutes(words: Int) -> Int { max(1, Int((Double(words) / 140).rounded())) }

    static func summary(words: Int) -> String {
        words == 0 ? "Empty" : "\(words) \(words == 1 ? "word" : "words") \u{00B7} \(minutes(words: words)) min aloud"
    }
}
