import Foundation

public struct AlignmentEvidence: Equatable, Sendable {
    public let matchedWordIndices: Set<Int>
    public let assessedWordIndices: Set<Int>

    public init(matchedWordIndices: Set<Int>, assessedWordIndices: Set<Int>) {
        self.matchedWordIndices = matchedWordIndices
        self.assessedWordIndices = assessedWordIndices
    }
}

public struct TrackingUpdate: Equatable, Sendable {
    public let wordIndex: Int?
    public let confirmedWordIndex: Int?
    public let isMatched: Bool
    public let isFinished: Bool
    public let evidence: AlignmentEvidence?
}

public struct ScriptTracker: Sendable {
    public let document: ScriptDocument
    public private(set) var currentWordIndex: Int?
    public private(set) var confirmedWordIndex: Int?
    private var currentEndUnit: Int?
    private var confirmedEndUnit: Int?
    private var selectedAnchor = 0
    private var finished = false
    private var pendingRecovery: (word: Int, text: String)?
    private var hypotheses: [HypothesisKey: HypothesisState] = [:]
    private var hypothesisOrder: [HypothesisKey] = []
    private var cursorHypothesis: HypothesisKey?
    private var confirmedHypothesis: HypothesisKey?
    private var cursorAudioEnd: Double?
    private var confirmedAudioEnd: Double?
    private var lastImplicitTokens: [String] = []
    private var implicitID = 0
    private var lastEvidenceTokens: [String] = []
    private var usesSelectedAnchor = false

    public init(document: ScriptDocument) { self.document = document }

    @discardableResult
    public mutating func consume(_ text: String, isFinal: Bool, hypothesisID: UInt64? = nil,
                                 segmentText: String? = nil, audioRange: Range<Double>? = nil) -> TrackingUpdate {
        let fullTokens = EnglishNormalizer.tokenize(text)
        guard !document.units.isEmpty else { return snapshot(matched: false) }
        guard !fullTokens.isEmpty else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? revokeTentative() : snapshot(matched: false)
        }
        // Bound each move from the displayed position, not a potentially old
        // final result: continuous speech can stay provisional across paragraphs.
        let allowedWords = searchWordRange()
        guard !allowedWords.isEmpty else { return snapshot(matched: false) }
        let allowedLower = document.wordUnitStarts[allowedWords.lowerBound]
        let allowedUpper = allowedWords.upperBound == document.words.count
            ? document.units.count : document.wordUnitStarts[allowedWords.upperBound]
        let allowedUnits = allowedLower..<allowedUpper
        let key: HypothesisKey
        if let hypothesisID {
            key = .audio(hypothesisID)
        } else {
            if !lastImplicitTokens.isEmpty,
               !fullTokens.starts(with: lastImplicitTokens), !lastImplicitTokens.starts(with: fullTokens) { implicitID += 1 }
            lastImplicitTokens = fullTokens
            key = .implicit(implicitID)
        }
        let segmentTokens = segmentText.map { $0 == text ? fullTokens : EnglishNormalizer.tokenize($0) }
        if let segmentTokens, segmentTokens.isEmpty {
            return segmentText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
                ? revokeTentative() : snapshot(matched: false)
        }
        // Old chunks provide transcript history, not evidence for the newest
        // audio. Otherwise one new common word can borrow an old phrase's score.
        let cursorTokens = segmentTokens ?? fullTokens
        let spoken = Array(cursorTokens.suffix(28))
        let newCount = segmentTokens?.count ?? (fullTokens.starts(with: lastEvidenceTokens)
            ? max(1, fullTokens.count - lastEvidenceTokens.count) : fullTokens.count)
        let newEnd = usesSelectedAnchor
            ? document.wordUnitStarts[selectedAnchor] + newCount - 1
            : (currentEndUnit ?? -1) + newCount
        let expectedNewEnd = min(document.units.count - 1, max(0, newEnd))
        let newAnchor = document.units[expectedNewEnd].wordIndex
        var state = hypotheses[key] ?? HypothesisState(anchorWord: newAnchor)
        let sharedPrefix = zip(state.tokens, cursorTokens).prefix { $0.0 == $0.1 }.count
        let addedCount = cursorTokens.count - sharedPrefix
        let superseded = isOlder(key, audioRange: audioRange, than: cursorHypothesis, audioEnd: cursorAudioEnd)
        if let end = state.endUnit, isFinal, !state.isFinalized,
           superseded || !allowedUnits.contains(end),
           let revision = pendingFinal(fullTokens, segmentTokens: segmentTokens, state: state) {
            // A matched partial may finalize, with revisions, after a newer
            // partial. Validate its scoring without rewinding the visible cursor.
            state.tokens = cursorTokens
            state.endUnit = revision.endUnit
            state.isFinalized = true
            hypotheses[key] = state
            if !isOlder(key, audioRange: audioRange, than: confirmedHypothesis, audioEnd: confirmedAudioEnd) {
                confirmedEndUnit = revision.endUnit
                confirmedWordIndex = document.units[revision.endUnit].wordIndex
                confirmedHypothesis = key
                confirmedAudioEnd = audioRange?.upperBound
            }
            lastEvidenceTokens = fullTokens
            return snapshot(matched: true, evidence: revision.evidence)
        }
        guard !superseded else { return snapshot(matched: false) }
        if let end = state.endUnit, cursorTokens == state.tokens, allowedUnits.contains(end) {
            accept(endUnit: end, isFinal: isFinal, hypothesis: key, audioRange: audioRange)
            state.isFinalized = state.isFinalized || isFinal
            state.searchUnits = allowedUnits
            hypotheses[key] = state
            lastEvidenceTokens = fullTokens
            return snapshot(matched: true, evidence: isFinal ? finalEvidence(segmentTokens ?? fullTokens, endingAt: end) : nil)
        }
        var anchorWord = state.anchorWord
        var shortRevisionEnd: Int?
        if let end = state.endUnit {
            let predictedUnit = min(document.units.count - 1, max(0, end + cursorTokens.count - state.tokens.count))
            anchorWord = document.units[predictedUnit].wordIndex
            if (1...2).contains(addedCount) {
                shortRevisionEnd = predictedUnit
            }
        }
        if hypotheses[key] == nil {
            hypothesisOrder.append(key)
            if hypothesisOrder.count > 32 { hypotheses.removeValue(forKey: hypothesisOrder.removeFirst()) }
            hypotheses[key] = state
        }
        anchorWord = min(allowedWords.upperBound - 1, max(allowedWords.lowerBound, anchorWord))
        let lowerWord = max(allowedWords.lowerBound, anchorWord - 36)
        let upperWord = min(allowedWords.upperBound, anchorWord + 100)
        let lower = document.wordUnitStarts[lowerWord]
        let upper = upperWord == document.words.count ? document.units.count : document.wordUnitStarts[upperWord]
        let recentCount = min(spoken.count, addedCount > 0 ? min(6, addedCount) : 6)
        let recentStart = spoken.count - recentCount
        let minimumRecentMatches = state.endUnit != nil && recentCount <= 2
            ? 1 : Int(ceil(Double(recentCount) * 0.65))
        let previousEnd = currentEndUnit ?? 0
        let shortNewSegmentEnd = state.endUnit == nil && spoken.count <= 2 ? expectedNewEnd : nil
        let supportsCurrentSpeech: (Alignment) -> Bool = { match in
            match.recentMatches >= minimumRecentMatches
                && (shortRevisionEnd.map { abs(match.endUnit - $0) <= 3 } ?? true)
                && (shortNewSegmentEnd.map { abs(match.endUnit - $0) <= 1 } ?? true)
                && (spoken.count > 2 || state.endUnit != nil
                    || match.endUnit >= previousEnd)
        }
        let local = candidates(spoken, in: lower..<upper, recentStart: recentStart).filter {
            acceptable($0, spokenCount: spoken.count, anchorWord: anchorWord, global: false)
                && supportsCurrentSpeech($0)
        }.sorted { rankedScore($0, anchor: anchorWord) > rankedScore($1, anchor: anchorWord) }

        var match = local.first
        let recoverySpoken = Array(spoken.suffix(recentCount))
        if match == nil, recoverySpoken.count >= 3 {
            var windows: [Range<Int>] = []
            for token in recoverySpoken.suffix(8) {
                guard let positions = document.positions[token] else { continue }
                let occurrences = positions.filter { allowedUnits.contains($0) }
                guard occurrences.count <= 16 else { continue }
                for position in occurrences {
                    let range = max(allowedLower, position - 32)..<min(allowedUpper, position + 33)
                    if !windows.contains(where: { abs($0.lowerBound - range.lowerBound) < 16 }) {
                        windows.append(range)
                    }
                }
            }
            var unique: [Int: Alignment] = [:]
            for window in windows.prefix(24) {
                for candidate in candidates(recoverySpoken, in: window)
                    where supportsCurrentSpeech(candidate)
                        && acceptable(candidate, spokenCount: recoverySpoken.count, anchorWord: anchorWord, global: true) {
                    if candidate.score > (unique[candidate.endUnit]?.score ?? 0) { unique[candidate.endUnit] = candidate }
                }
            }
            let global = unique.values.sorted { $0.score > $1.score }
            if let best = global.first, global.dropFirst().allSatisfy({ best.score - $0.score >= 3 }) {
                let word = document.units[best.endUnit].wordIndex
                let corroborated = pendingRecovery.map { abs($0.word - word) <= 8 && $0.text != text } ?? false
                pendingRecovery = (word, text)
                if isFinal || corroborated || recoverySpoken.count <= 4 { match = best }
            }
        }
        guard let match else { return snapshot(matched: false) }
        state.tokens = cursorTokens
        state.endUnit = match.endUnit
        state.isFinalized = isFinal
        state.searchUnits = allowedUnits
        state.recentTokenCount = recentCount
        hypotheses[key] = state
        lastEvidenceTokens = fullTokens
        accept(endUnit: match.endUnit, isFinal: isFinal, hypothesis: key, audioRange: audioRange)
        pendingRecovery = nil
        return snapshot(matched: true, evidence: isFinal ? finalEvidence(segmentTokens ?? fullTokens, endingAt: match.endUnit) : nil)
    }

    public mutating func select(wordIndex: Int) {
        guard document.words.indices.contains(wordIndex) else { return }
        selectedAnchor = wordIndex
        currentWordIndex = wordIndex
        confirmedWordIndex = wordIndex
        let end = wordIndex + 1 < document.wordUnitStarts.count ? document.wordUnitStarts[wordIndex + 1] - 1 : document.units.count - 1
        currentEndUnit = end
        confirmedEndUnit = end
        finished = false
        pendingRecovery = nil
        clearHypotheses()
        usesSelectedAnchor = true
    }

    public mutating func reset() {
        currentWordIndex = nil
        confirmedWordIndex = nil
        currentEndUnit = nil
        confirmedEndUnit = nil
        selectedAnchor = 0
        pendingRecovery = nil
        finished = false
        clearHypotheses()
        usesSelectedAnchor = false
    }

    public mutating func revokeTentative() -> TrackingUpdate {
        retractWithinSearchBounds()
        clearHypotheses()
        return snapshot(matched: false)
    }

    private func searchWordRange() -> Range<Int> {
        document.trackingWordRange(around: currentWordIndex ?? selectedAnchor)
    }

    private func isOlder(_ key: HypothesisKey, audioRange: Range<Double>?,
                         than reference: HypothesisKey?, audioEnd: Double?) -> Bool {
        // Overlapping ranges may merge and reuse an earlier identity. Audio time,
        // not identity allocation order or manuscript position, defines recency.
        if let audioRange, let audioEnd { return audioRange.upperBound < audioEnd - 0.001 }
        guard let reference, key != reference,
              let incoming = hypothesisOrder.firstIndex(of: key),
              let current = hypothesisOrder.firstIndex(of: reference) else { return false }
        return incoming < current
    }

    private mutating func retractWithinSearchBounds() {
        let allowed = searchWordRange()
        if let confirmedWordIndex, allowed.contains(confirmedWordIndex) {
            currentWordIndex = confirmedWordIndex
            currentEndUnit = confirmedEndUnit
        } else if confirmedWordIndex == nil, allowed.contains(0) {
            currentWordIndex = nil
            currentEndUnit = nil
        }
        finished = false
    }

    public mutating func beginSession() {
        if !usesSelectedAnchor {
            selectedAnchor = min((currentWordIndex ?? -1) + 1, max(0, document.words.count - 1))
        }
        usesSelectedAnchor = true
        pendingRecovery = nil
        clearHypotheses()
    }

    private mutating func clearHypotheses() {
        hypotheses.removeAll()
        hypothesisOrder.removeAll()
        cursorHypothesis = nil
        confirmedHypothesis = nil
        cursorAudioEnd = nil
        confirmedAudioEnd = nil
        lastImplicitTokens.removeAll()
        lastEvidenceTokens.removeAll()
        implicitID = 0
    }

    private mutating func accept(endUnit: Int, isFinal: Bool, hypothesis: HypothesisKey, audioRange: Range<Double>?) {
        let word = document.units[endUnit].wordIndex
        currentWordIndex = word
        currentEndUnit = endUnit
        cursorHypothesis = hypothesis
        cursorAudioEnd = audioRange?.upperBound
        usesSelectedAnchor = false
        if isFinal {
            confirmedWordIndex = word
            confirmedEndUnit = endUnit
            confirmedHypothesis = hypothesis
            confirmedAudioEnd = audioRange?.upperBound
        }
        finished = isFinal && word == document.words.count - 1
    }

    private func snapshot(matched: Bool, evidence: AlignmentEvidence? = nil) -> TrackingUpdate {
        TrackingUpdate(wordIndex: currentWordIndex, confirmedWordIndex: confirmedWordIndex,
                       isMatched: matched, isFinished: finished, evidence: evidence)
    }

    private func pendingFinal(_ tokens: [String], segmentTokens: [String]?, state: HypothesisState)
        -> (endUnit: Int, evidence: AlignmentEvidence)? {
        guard let end = state.endUnit, let bounds = state.searchUnits else { return nil }
        let anchor = document.units[end].wordIndex
        let lowerWord = max(0, anchor - 36)
        let upperWord = min(document.words.count, anchor + 100)
        let lower = max(bounds.lowerBound, document.wordUnitStarts[lowerWord])
        let upper = min(bounds.upperBound, upperWord == document.words.count
            ? document.units.count : document.wordUnitStarts[upperWord])
        guard lower < upper else { return nil }
        let cursorTokens = segmentTokens ?? tokens
        let spoken = Array(cursorTokens.suffix(28))
        let sharedPrefix = zip(state.tokens, cursorTokens).prefix { $0.0 == $0.1 }.count
        let prefixRelated = sharedPrefix == min(state.tokens.count, cursorTokens.count)
        let revisedCount = prefixRelated
            ? state.recentTokenCount + cursorTokens.count - state.tokens.count
            : cursorTokens.count - sharedPrefix
        let recentStart = spoken.count - min(spoken.count, max(1, min(6, revisedCount)))
        let recentCount = spoken.count - recentStart
        let minimumRecentMatches = recentCount <= 2 ? 1 : Int(ceil(Double(recentCount) * 0.65))
        let changedCount = cursorTokens.count - sharedPrefix
        let predictedEnd = end + cursorTokens.count - state.tokens.count
        let matches = candidates(spoken, in: lower..<upper, recentStart: recentStart).filter {
            acceptable($0, spokenCount: spoken.count, anchorWord: anchor, global: false)
                && $0.recentMatches >= minimumRecentMatches
                && (!(1...2).contains(changedCount) || abs($0.endUnit - predictedEnd) <= 3)
        }.sorted { rankedScore($0, anchor: anchor) > rankedScore($1, anchor: anchor) }
        guard let match = matches.first,
              let evidence = finalEvidence(segmentTokens ?? tokens, endingAt: match.endUnit) else { return nil }
        return (match.endUnit, evidence)
    }

    private func finalEvidence(_ tokens: [String], endingAt endUnit: Int) -> AlignmentEvidence? {
        guard !tokens.isEmpty else { return nil }
        let exactStart = endUnit - tokens.count + 1
        if exactStart >= 0, tokens.indices.allSatisfy({
            similarity(tokens[$0], document.units[exactStart + $0].text) == 3
        }) {
            let words = Set((exactStart...endUnit).map { document.units[$0].wordIndex })
            return AlignmentEvidence(matchedWordIndices: words, assessedWordIndices: words)
        }
        // Coverage needs more context than the deliberately short cursor window.
        // Bound both dimensions so unusually long ASR results cannot grow a
        // quadratic matrix. Never truncate a final into an apparent skipped gap.
        guard tokens.count <= 512 else { return nil }
        let spoken = tokens
        let lower = max(0, endUnit - min(2_048, spoken.count * 3 + 32) + 1)
        let anchor = document.units[endUnit].wordIndex
        guard let alignment = candidates(spoken, in: lower..<(endUnit + 1), endingAt: endUnit).first,
              acceptable(alignment, spokenCount: spoken.count, anchorWord: anchor, global: false),
              let firstMatchedUnit = alignment.matchedUnits.min() else { return nil }
        let matchedWords = Set(alignment.matchedUnits.map { document.units[$0].wordIndex })
        let firstWord = document.units[firstMatchedUnit].wordIndex
        return AlignmentEvidence(matchedWordIndices: matchedWords, assessedWordIndices: Set(firstWord...anchor))
    }

    private func rankedScore(_ match: Alignment, anchor: Int) -> Double {
        let distance = abs(document.units[match.endUnit].wordIndex - anchor)
        return match.score - min(Double(distance) * 0.075, 4)
    }

    private func acceptable(_ match: Alignment, spokenCount: Int, anchorWord: Int, global: Bool) -> Bool {
        let coverage = Double(match.matches) / Double(spokenCount - match.spokenStart)
        if global {
            if spokenCount <= 4 { return match.exact == spokenCount && match.spokenStart == 0 }
            return match.matches >= 5 && match.exact >= 4 && coverage >= 0.85
        }
        if spokenCount <= 2 {
            return match.exact == spokenCount && abs(document.units[match.endUnit].wordIndex - anchorWord) <= 3
        }
        return match.matches >= 3 && coverage >= 0.65 && match.score >= 6
    }

    // Local sequence alignment permits insertions/deletions, but a cursor can
    // only end on the newest spoken token, never on unspoken script words.
    private func candidates(_ spoken: [String], in range: Range<Int>, endingAt endUnit: Int? = nil,
                            recentStart: Int = 0) -> [Alignment] {
        let count = range.count
        guard count > 0 else { return [] }
        let width = count + 1
        var scores = [Double](repeating: 0, count: (spoken.count + 1) * width)
        var traces = [UInt8](repeating: 0, count: scores.count)
        var endings: [(column: Int, score: Double)] = []
        for row in 1...spoken.count {
            for column in 1...count {
                let index = row * width + column
                let similarity = similarity(spoken[row - 1], document.units[range.lowerBound + column - 1].text)
                let diagonal = scores[index - width - 1] + similarity
                let up = scores[index - width] - 1.7
                let left = scores[index - 1] - 1.7
                let best = max(0, diagonal, up, left)
                scores[index] = best
                if best > 0 { traces[index] = best == diagonal ? 1 : (best == up ? 2 : 3) }
                if row == spoken.count, similarity > 0, traces[index] == 1, best > 0,
                   endUnit == nil || range.lowerBound + column - 1 == endUnit {
                    endings.append((column, best))
                }
            }
        }
        return endings.map { ending in
            var row = spoken.count
            var column = ending.column
            var matches = 0
            var exact = 0
            var recentMatches = 0
            var matchedUnits: Set<Int> = []
            while row > 0, column > 0, scores[row * width + column] > 0 {
                switch traces[row * width + column] {
                case 1:
                    let left = spoken[row - 1]
                    let right = document.units[range.lowerBound + column - 1].text
                    if similarity(left, right) > 0 {
                        matches += 1
                        matchedUnits.insert(range.lowerBound + column - 1)
                        if row - 1 >= recentStart { recentMatches += 1 }
                    }
                    if similarity(left, right) == 3 { exact += 1 }
                    row -= 1
                    column -= 1
                case 2: row -= 1
                case 3: column -= 1
                default: row = 0
                }
            }
            return Alignment(endUnit: range.lowerBound + ending.column - 1, spokenStart: row,
                             matches: matches, exact: exact, score: ending.score, matchedUnits: matchedUnits,
                             recentMatches: recentMatches)
        }
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        if lhs == rhs { return 3 }
        if (lhs == "<is-or-has>" && ["is", "has"].contains(rhs))
            || (rhs == "<is-or-has>" && ["is", "has"].contains(lhs)) { return 3 }
        guard lhs.count >= 5, rhs.count >= 5, lhs.first == rhs.first, abs(lhs.count - rhs.count) <= 1 else { return -2.4 }
        let left = Array(lhs)
        let right = Array(rhs)
        var i = 0, j = 0, edits = 0
        while i < left.count, j < right.count {
            if left[i] == right[j] { i += 1; j += 1; continue }
            edits += 1
            if edits > 1 { return -2.4 }
            if left.count >= right.count { i += 1 }
            if right.count >= left.count { j += 1 }
        }
        edits += left.count - i + right.count - j
        return edits <= 1 ? 1.6 : -2.4
    }
}

private enum HypothesisKey: Hashable, Sendable {
    case audio(UInt64)
    case implicit(Int)
}

private struct HypothesisState: Sendable {
    let anchorWord: Int
    var tokens: [String] = []
    var endUnit: Int?
    var isFinalized = false
    var searchUnits: Range<Int>?
    var recentTokenCount = 6
}

private struct Alignment {
    let endUnit: Int
    let spokenStart: Int
    let matches: Int
    let exact: Int
    let score: Double
    let matchedUnits: Set<Int>
    let recentMatches: Int
}
