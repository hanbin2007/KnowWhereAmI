import Foundation

enum EnglishNormalizer {
    // This expression is constant, not derived from manuscript input.
    static let wordExpression = try! NSRegularExpression(pattern: #"[\p{L}\p{N}]+(?:['\u2019][\p{L}\p{N}]+)*"#)

    private static let contractions: [String: [String]] = [
        "im": ["i", "am"], "ive": ["i", "have"], "ill": ["i", "will"],
        "youre": ["you", "are"], "youve": ["you", "have"], "youll": ["you", "will"],
        "were": ["we", "are"], "weve": ["we", "have"], "well": ["we", "will"],
        "theyre": ["they", "are"], "theyve": ["they", "have"], "theyll": ["they", "will"],
        "its": ["it", "<is-or-has>"], "thats": ["that", "<is-or-has>"], "theres": ["there", "<is-or-has>"],
        "hes": ["he", "<is-or-has>"], "shes": ["she", "<is-or-has>"],
        "whos": ["who", "<is-or-has>"], "whats": ["what", "<is-or-has>"],
        "hell": ["he", "will"], "shell": ["she", "will"],
        "dont": ["do", "not"], "doesnt": ["does", "not"], "didnt": ["did", "not"],
        "cant": ["can", "not"], "cannot": ["can", "not"], "wont": ["will", "not"],
        "isnt": ["is", "not"], "arent": ["are", "not"], "wasnt": ["was", "not"],
        "werent": ["were", "not"], "couldnt": ["could", "not"], "wouldnt": ["would", "not"],
        "shouldnt": ["should", "not"], "havent": ["have", "not"], "hasnt": ["has", "not"],
        "lets": ["let", "us"]
    ]
    static let fillers: Set<String> = ["um", "uh", "umm", "uhh", "erm", "hmm"]

    static func tokenize(_ text: String) -> [String] {
        let source = text as NSString
        return wordExpression.matches(in: text, range: NSRange(location: 0, length: source.length))
            .flatMap { units(for: source.substring(with: $0.range)) }
            .filter { !fillers.contains($0) }
    }

    static func units(for raw: String) -> [String] {
        let folded = raw.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let key = folded.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
        // Apostrophe-free "were", "well", "its" and "ill" remain ordinary words.
        if (folded.contains("'") || folded.contains("\u{2019}") || key == "cannot"), let expansion = contractions[key] {
            return expansion
        }
        if raw.allSatisfy(\.isNumber), raw.count <= 9, let number = Int(raw) {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.numberStyle = .spellOut
            if raw.count > 1, raw.first == "0" {
                return raw.flatMap { digit in
                    formatter.string(from: NSNumber(value: Int(String(digit)) ?? 0))?.components(separatedBy: " ") ?? []
                }
            }
            if let spelled = formatter.string(from: NSNumber(value: number)) {
                return spelled.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty && $0 != "and" }
            }
        }
        return key.isEmpty ? [] : [key]
    }
}
