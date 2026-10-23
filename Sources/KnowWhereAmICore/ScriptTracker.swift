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
    private var recoverySpeech: [PendingSpeech] = []
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
        var continuationEnd = expectedNewEnd
        if let end = state.endUnit {
            let predictedUnit = min(document.units.count - 1, max(0, end + cursorTokens.count - state.tokens.count))
            anchorWord = document.units[predictedUnit].wordIndex
            continuationEnd = predictedUnit
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
        let retracting = state.endUnit != nil && cursorTokens.count < state.tokens.count
            && state.tokens.starts(with: cursorTokens)
        let agreement = zip(state.tokens, cursorTokens).filter { $0.0 == $0.1 }.count
        let replacing = state.endUnit != nil && !state.tokens.starts(with: cursorTokens)
            && !cursorTokens.starts(with: state.tokens)
            && Double(agreement) < Double(min(state.tokens.count, cursorTokens.count)) * 0.65
        let freshTokens: [String]
        if state.endUnit != nil { freshTokens = Array(cursorTokens.dropFirst(sharedPrefix)) }
        else if segmentTokens == nil, fullTokens.starts(with: lastEvidenceTokens) {
            freshTokens = Array(fullTokens.suffix(newCount))
        } else { freshTokens = cursorTokens }
        let recoveryWindows = updateRecoverySpeech(freshTokens, key: key, audioRange: audioRange)
        let continuation = exactContinuation(cursorTokens, endingAt: continuationEnd,
                                             bounds: allowedUnits, recentCount: recentCount).flatMap {
            supportsMovement($0, retracting: retracting, replacing: replacing) ? $0 : nil
        }
        let local = continuation.map { [$0] } ?? candidates(spoken, in: lower..<upper, recentStart: recentStart).filter {
            supportsMovement($0, retracting: retracting, replacing: replacing)
        }
        let trustedContinuation = recoveryWindows.contains(where: { $0.count > recentCount }) ? nil : continuation
        var movement = local
        let localBest = trustedContinuation ?? chooseMovement(local, anchor: anchorWord, retracting: retracting)
        let certainNearby = localBest.map {
            abs(document.units[$0.endUnit].wordIndex - (currentWordIndex ?? selectedAnchor)) <= 3
                && $0.recentExact == recentCount && recoveryWindows.allSatisfy { $0.count <= recentCount }
        } ?? false
        if trustedContinuation == nil, !certainNearby {
            for spoken in recoveryWindows {
                movement += recoveryCandidates(spoken, in: allowedUnits).filter {
                    supportsMovement($0, retracting: false, replacing: replacing)
                }
            }
        }
        guard let match = trustedContinuation ?? chooseMovement(movement, anchor: anchorWord, retracting: retracting) else {
            return snapshot(matched: false)
        }
        state.tokens = cursorTokens
        state.endUnit = match.endUnit
        state.isFinalized = isFinal
        state.searchUnits = allowedUnits
        state.recentTokenCount = match.recentCount
        hypotheses[key] = state
        lastEvidenceTokens = fullTokens
        accept(endUnit: match.endUnit, isFinal: isFinal, hypothesis: key, audioRange: audioRange)
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
        clearHypotheses()
        usesSelectedAnchor = true
    }

    public mutating func reset() {
        currentWordIndex = nil
        confirmedWordIndex = nil
        currentEndUnit = nil
        confirmedEndUnit = nil
        selectedAnchor = 0
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

    private func supportsMovement(_ match: Alignment, retracting: Bool, replacing: Bool) -> Bool {
        let displacement = document.units[match.endUnit].wordIndex - (currentWordIndex ?? selectedAnchor)
        return TrackingSensitivity(displacement: displacement, retractingKnownSpeech: retracting,
                                   replacingHypothesis: replacing)
            .accepts(matches: match.recentMatches, exact: match.recentExact, observed: match.recentCount)
    }

    private func exactContinuation(_ tokens: [String], endingAt end: Int, bounds: Range<Int>,
                                   recentCount: Int) -> Alignment? {
        let start = end - tokens.count + 1
        guard start >= 0, bounds.contains(end), tokens.indices.allSatisfy({
            similarity(tokens[$0], document.units[start + $0].text) == 3
        }) else { return nil }
        let count = min(28, tokens.count)
        return Alignment(endUnit: end, spokenStart: 0, matches: count, exact: count,
                         score: Double(count) * 3, matchedUnits: Set((end - count + 1)...end),
                         recentMatches: recentCount, recentExact: recentCount, recentCount: recentCount)
    }

    private func chooseMovement(_ matches: [Alignment], anchor: Int, retracting: Bool) -> Alignment? {
        let ranked = matches.sorted {
            let left = rankedScore($0, anchor: anchor)
            let right = rankedScore($1, anchor: anchor)
            return left == right ? $0.endUnit < $1.endUnit : left > right
        }
        guard let best = ranked.first else { return nil }
        let word = document.units[best.endUnit].wordIndex
        let sensitivity = TrackingSensitivity(displacement: word - (currentWordIndex ?? selectedAnchor),
                                              retractingKnownSpeech: retracting)
        if let alternative = ranked.dropFirst().first(where: {
            abs(document.units[$0.endUnit].wordIndex - word) > 3
        }), rankedScore(best, anchor: anchor) - rankedScore(alternative, anchor: anchor) < sensitivity.ambiguityMargin {
            return nil
        }
        return best
    }

    private mutating func updateRecoverySpeech(_ tokens: [String], key: HypothesisKey,
                                               audioRange: Range<Double>?) -> [[String]] {
        recoverySpeech.removeAll { previous in
            if previous.key == key { return true }
            guard let earlier = previous.audioRange, let audioRange else { return false }
            return earlier.lowerBound < audioRange.upperBound - 0.001
                && earlier.upperBound > audioRange.lowerBound + 0.001
        }
        if !tokens.isEmpty {
            recoverySpeech.append(PendingSpeech(key: key, tokens: Array(tokens.suffix(6)), audioRange: audioRange))
        }
        let order = hypothesisOrder
        recoverySpeech.sort {
            if let left = $0.audioRange, let right = $1.audioRange { return left.lowerBound < right.lowerBound }
            return (order.firstIndex(of: $0.key) ?? 0) < (order.firstIndex(of: $1.key) ?? 0)
        }
        if recoverySpeech.count > 8 { recoverySpeech.removeFirst(recoverySpeech.count - 8) }
        // An older final cannot use future provisional words to confirm a move.
        let eligible = recoverySpeech.filter {
            !isOlder(key, audioRange: audioRange, than: $0.key, audioEnd: $0.audioRange?.upperBound)
        }
        var windows: [[String]] = []
        for start in eligible.indices {
            let words = Array(eligible[start...].flatMap(\.tokens).suffix(6))
            if words.count >= 2, !windows.contains(words) { windows.append(words) }
        }
        return windows
    }

    private func recoveryCandidates(_ spoken: [String], in bounds: Range<Int>) -> [Alignment] {
        var unique: [Int: Alignment] = [:]
        for match in exactCandidates(spoken, in: bounds) { unique[match.endUnit] = match }
        var windows: [Range<Int>] = []
        for token in spoken {
            guard let positions = document.positions[token] else { continue }
            let occurrences = positions.filter { bounds.contains($0) }
            guard occurrences.count <= 16 else { continue }
            for position in occurrences {
                let range = max(bounds.lowerBound, position - 32)..<min(bounds.upperBound, position + 33)
                if !windows.contains(where: { abs($0.lowerBound - range.lowerBound) < 16 }) { windows.append(range) }
            }
        }
        for window in windows.prefix(24) {
            for match in candidates(spoken, in: window) where match.score > (unique[match.endUnit]?.score ?? 0) {
                unique[match.endUnit] = match
            }
        }
        return Array(unique.values)
    }

    private func exactCandidates(_ spoken: [String], in bounds: Range<Int>) -> [Alignment] {
        var seed: (offset: Int, positions: [Int])?
        for (offset, token) in spoken.enumerated() {
            guard let positions = document.positions[token] else { continue }
            if let previous = seed, previous.positions.count <= positions.count { continue }
            seed = (offset, positions)
        }
        guard let seed else { return [] }
        var matches: [Alignment] = []
        for position in seed.positions where bounds.contains(position) {
            let start = position - seed.offset
            let end = start + spoken.count - 1
            guard start >= bounds.lowerBound, end < bounds.upperBound,
                  spoken.indices.allSatisfy({ similarity(spoken[$0], document.units[start + $0].text) == 3 }) else { continue }
            matches.append(Alignment(endUnit: end, spokenStart: 0, matches: spoken.count, exact: spoken.count,
                                     score: Double(spoken.count) * 3, matchedUnits: Set(start...end),
                                     recentMatches: spoken.count, recentExact: spoken.count, recentCount: spoken.count))
            if matches.count == 64 { break }
        }
        return matches
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
        clearHypotheses()
    }

    private mutating func clearHypotheses() {
        hypotheses.removeAll()
        recoverySpeech.removeAll()
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
        recoverySpeech = recoverySpeech.filter {
            isOlder(hypothesis, audioRange: audioRange, than: $0.key, audioEnd: $0.audioRange?.upperBound)
        }
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
            acceptableEvidence($0, spokenCount: spoken.count, anchorWord: anchor)
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
              acceptableEvidence(alignment, spokenCount: spoken.count, anchorWord: anchor),
              let firstMatchedUnit = alignment.matchedUnits.min() else { return nil }
        let matchedWords = Set(alignment.matchedUnits.map { document.units[$0].wordIndex })
        let firstWord = document.units[firstMatchedUnit].wordIndex
        return AlignmentEvidence(matchedWordIndices: matchedWords, assessedWordIndices: Set(firstWord...anchor))
    }

    private func rankedScore(_ match: Alignment, anchor: Int) -> Double {
        let distance = abs(document.units[match.endUnit].wordIndex - anchor)
        let context = match.score / Double(max(1, match.matches))
        return Double(match.recentMatches) * 3 + Double(match.recentExact) * 1.5
            + context - log1p(Double(distance)) * 0.5
    }

    private func acceptableEvidence(_ match: Alignment, spokenCount: Int, anchorWord: Int) -> Bool {
        let coverage = Double(match.matches) / Double(spokenCount - match.spokenStart)
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
            var recentExact = 0
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
                    if similarity(left, right) == 3 {
                        exact += 1
                        if row - 1 >= recentStart { recentExact += 1 }
                    }
                    row -= 1
                    column -= 1
                case 2: row -= 1
                case 3: column -= 1
                default: row = 0
                }
            }
            return Alignment(endUnit: range.lowerBound + ending.column - 1, spokenStart: row,
                             matches: matches, exact: exact, score: ending.score, matchedUnits: matchedUnits,
                             recentMatches: recentMatches, recentExact: recentExact,
                             recentCount: spoken.count - recentStart)
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
    let recentExact: Int
    let recentCount: Int
}

private struct PendingSpeech {
    let key: HypothesisKey
    let tokens: [String]
    let audioRange: Range<Double>?
}
