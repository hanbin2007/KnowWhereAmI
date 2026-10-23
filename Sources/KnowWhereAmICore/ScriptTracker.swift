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
    private var trackingAnchorWord = 0
    private var finished = false
    private var pendingRecovery: (word: Int, text: String)?
    private var hypotheses: [HypothesisKey: HypothesisState] = [:]
    private var hypothesisOrder: [HypothesisKey] = []
    private var lastImplicitTokens: [String] = []
    private var implicitID = 0
    private var lastEvidenceTokens: [String] = []
    private var usesSelectedAnchor = false

    public init(document: ScriptDocument) { self.document = document }

    @discardableResult
    public mutating func consume(_ text: String, isFinal: Bool, hypothesisID: UInt64? = nil, segmentText: String? = nil) -> TrackingUpdate {
        let fullTokens = EnglishNormalizer.tokenize(text)
        guard !document.units.isEmpty else { return snapshot(matched: false) }
        guard !fullTokens.isEmpty else { return revokeTentative() }
        // Volatile hypotheses cannot move the search fence; only finalized speech
        // or an explicit user re-anchor can change its reference position.
        let allowedWords = searchWordRange()
        guard !allowedWords.isEmpty else { return snapshot(matched: false) }
        let allowedLower = document.wordUnitStarts[allowedWords.lowerBound]
        let allowedUpper = allowedWords.upperBound == document.words.count
            ? document.units.count : document.wordUnitStarts[allowedWords.upperBound]
        let allowedUnits = allowedLower..<allowedUpper
        let spoken = Array(fullTokens.suffix(28))
        let key: HypothesisKey
        if let hypothesisID {
            key = .audio(hypothesisID)
        } else {
            if !lastImplicitTokens.isEmpty,
               !fullTokens.starts(with: lastImplicitTokens), !lastImplicitTokens.starts(with: fullTokens) { implicitID += 1 }
            lastImplicitTokens = fullTokens
            key = .implicit(implicitID)
        }
        let segmentTokens = segmentText.map(EnglishNormalizer.tokenize)
        if let segmentTokens, segmentTokens.isEmpty {
            return hypotheses[key] == nil ? snapshot(matched: false) : revokeTentative()
        }
        let newCount = segmentTokens?.count ?? (fullTokens.starts(with: lastEvidenceTokens)
            ? max(1, fullTokens.count - lastEvidenceTokens.count) : fullTokens.count)
        let newEnd = usesSelectedAnchor
            ? document.wordUnitStarts[selectedAnchor] + newCount - 1
            : (currentEndUnit ?? -1) + newCount
        let newAnchor = document.units[min(document.units.count - 1, max(0, newEnd))].wordIndex
        var state = hypotheses[key] ?? HypothesisState(anchorWord: newAnchor)
        if let end = state.endUnit, isFinal, !state.isFinalized,
           !allowedUnits.contains(end),
           let revision = pendingFinal(fullTokens, segmentTokens: segmentTokens, state: state) {
            // A matched partial may finalize, with revisions, after a newer
            // partial. Validate its scoring without rewinding the visible cursor.
            state.tokens = fullTokens
            state.endUnit = revision.endUnit
            state.isFinalized = true
            hypotheses[key] = state
            if revision.endUnit > (confirmedEndUnit ?? -1) {
                confirmedEndUnit = revision.endUnit
                confirmedWordIndex = document.units[revision.endUnit].wordIndex
                trackingAnchorWord = document.units[revision.endUnit].wordIndex
            }
            lastEvidenceTokens = fullTokens
            return snapshot(matched: true, evidence: revision.evidence)
        }
        if let end = state.endUnit, fullTokens == state.tokens, allowedUnits.contains(end) {
            accept(endUnit: end, isFinal: isFinal)
            state.isFinalized = state.isFinalized || isFinal
            state.searchUnits = allowedUnits
            hypotheses[key] = state
            lastEvidenceTokens = fullTokens
            return snapshot(matched: true, evidence: isFinal ? finalEvidence(segmentTokens ?? fullTokens, endingAt: end) : nil)
        }
        var anchorWord = state.anchorWord
        if let end = state.endUnit,
           fullTokens.starts(with: state.tokens) || state.tokens.starts(with: fullTokens) {
            let predictedUnit = min(document.units.count - 1, max(0, end + fullTokens.count - state.tokens.count))
            anchorWord = document.units[predictedUnit].wordIndex
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
        let local = candidates(spoken, in: lower..<upper).filter {
            acceptable($0, spokenCount: spoken.count, anchorWord: anchorWord, global: false)
        }.sorted { rankedScore($0, anchor: anchorWord) > rankedScore($1, anchor: anchorWord) }

        var match = local.first
        if match == nil, spoken.count >= 5 {
            var windows: [Range<Int>] = []
            for token in spoken.suffix(8) {
                guard let occurrences = document.positions[token], occurrences.count <= 16 else { continue }
                for position in occurrences where allowedUnits.contains(position) {
                    let range = max(allowedLower, position - 32)..<min(allowedUpper, position + 33)
                    if !windows.contains(where: { abs($0.lowerBound - range.lowerBound) < 16 }) {
                        windows.append(range)
                    }
                }
            }
            var unique: [Int: Alignment] = [:]
            for window in windows.prefix(24) {
                for candidate in candidates(spoken, in: window) where acceptable(candidate, spokenCount: spoken.count, anchorWord: anchorWord, global: true) {
                    if candidate.score > (unique[candidate.endUnit]?.score ?? 0) { unique[candidate.endUnit] = candidate }
                }
            }
            let global = unique.values.sorted { $0.score > $1.score }
            if let best = global.first, global.dropFirst().allSatisfy({ best.score - $0.score >= 3 }) {
                let word = document.units[best.endUnit].wordIndex
                let corroborated = pendingRecovery.map { abs($0.word - word) <= 8 && $0.text != text } ?? false
                pendingRecovery = (word, text)
                if isFinal || corroborated { match = best }
            }
        }
        guard let match else {
            if !fullTokens.starts(with: lastEvidenceTokens) {
                retractWithinSearchBounds()
            }
            return snapshot(matched: false)
        }
        state.tokens = fullTokens
        state.endUnit = match.endUnit
        state.isFinalized = isFinal
        state.searchUnits = allowedUnits
        hypotheses[key] = state
        lastEvidenceTokens = fullTokens
        accept(endUnit: match.endUnit, isFinal: isFinal)
        pendingRecovery = nil
        return snapshot(matched: true, evidence: isFinal ? finalEvidence(segmentTokens ?? fullTokens, endingAt: match.endUnit) : nil)
    }

    public mutating func select(wordIndex: Int) {
        guard document.words.indices.contains(wordIndex) else { return }
        selectedAnchor = wordIndex
        trackingAnchorWord = wordIndex
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
        trackingAnchorWord = 0
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
        let anchored = document.trackingWordRange(around: trackingAnchorWord)
        let visible = document.trackingWordRange(around: currentWordIndex ?? trackingAnchorWord)
        let lower = max(anchored.lowerBound, visible.lowerBound)
        return lower..<max(lower, min(anchored.upperBound, visible.upperBound))
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
        trackingAnchorWord = selectedAnchor
        usesSelectedAnchor = true
        pendingRecovery = nil
        clearHypotheses()
    }

    private mutating func clearHypotheses() {
        hypotheses.removeAll()
        hypothesisOrder.removeAll()
        lastImplicitTokens.removeAll()
        lastEvidenceTokens.removeAll()
        implicitID = 0
    }

    private mutating func accept(endUnit: Int, isFinal: Bool) {
        let word = document.units[endUnit].wordIndex
        currentWordIndex = word
        currentEndUnit = endUnit
        usesSelectedAnchor = false
        if isFinal {
            confirmedWordIndex = word
            confirmedEndUnit = endUnit
            trackingAnchorWord = word
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
        let spoken = Array(tokens.suffix(28))
        let matches = candidates(spoken, in: lower..<upper).filter {
            acceptable($0, spokenCount: spoken.count, anchorWord: anchor, global: false)
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
        if global { return match.matches >= 5 && match.exact >= 4 && coverage >= 0.85 }
        if spokenCount <= 2 {
            return match.exact == spokenCount && abs(document.units[match.endUnit].wordIndex - anchorWord) <= 3
        }
        return match.matches >= 3 && coverage >= 0.65 && match.score >= 6
    }

    // Local sequence alignment permits insertions/deletions, but a cursor can
    // only end on the newest spoken token, never on unspoken script words.
    private func candidates(_ spoken: [String], in range: Range<Int>, endingAt endUnit: Int? = nil) -> [Alignment] {
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
            var matchedUnits: Set<Int> = []
            while row > 0, column > 0, scores[row * width + column] > 0 {
                switch traces[row * width + column] {
                case 1:
                    let left = spoken[row - 1]
                    let right = document.units[range.lowerBound + column - 1].text
                    if similarity(left, right) > 0 {
                        matches += 1
                        matchedUnits.insert(range.lowerBound + column - 1)
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
                             matches: matches, exact: exact, score: ending.score, matchedUnits: matchedUnits)
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
}

private struct Alignment {
    let endUnit: Int
    let spokenStart: Int
    let matches: Int
    let exact: Int
    let score: Double
    let matchedUnits: Set<Int>
}
