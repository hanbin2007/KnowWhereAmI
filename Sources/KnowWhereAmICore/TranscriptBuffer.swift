import Foundation

public struct SpeechChunk: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public let text: String
    public let isFinal: Bool
    public let wordTimings: [SpeechWordTiming]

    public init(start: Double, end: Double, text: String, isFinal: Bool, wordTimings: [SpeechWordTiming] = []) {
        self.start = start
        self.end = end
        self.text = text
        self.isFinal = isFinal
        self.wordTimings = wordTimings
    }
}

public struct SpeechWordTiming: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public let wordCount: Int

    public init(start: Double, end: Double, wordCount: Int = 1) {
        self.start = start
        self.end = end
        self.wordCount = wordCount
    }
}

public struct TranscriptBuffer: Sendable {
    private var chunks: [StoredChunk] = []
    private var finalizedThrough: Double = 0
    private var nextIdentity: UInt64 = 0
    public init() {}
    public var text: String { chunks.map(\.chunk.text).joined(separator: " ") }
    public var finalizedText: String { chunks.filter(\.chunk.isFinal).map(\.chunk.text).joined(separator: " ") }
    public var hasTentativeText: Bool { chunks.contains { !$0.chunk.isFinal } }
    public var hypothesisID: UInt64? { chunks.last?.identity }
    public var finalizedHypothesisID: UInt64? { chunks.last(where: \.chunk.isFinal)?.identity }
    public var segmentText: String? { chunks.last?.chunk.text }
    public var finalizedSegmentText: String? { chunks.last(where: \.chunk.isFinal)?.chunk.text }
    public var segmentAudioRange: Range<Double>? { chunks.last.map { $0.chunk.start..<$0.chunk.end } }
    public var finalizedSegmentAudioRange: Range<Double>? {
        chunks.last(where: \.chunk.isFinal).map { $0.chunk.start..<$0.chunk.end }
    }

    @discardableResult
    public mutating func ingest(_ chunk: SpeechChunk) -> Bool {
        guard chunk.start.isFinite, chunk.end.isFinite, chunk.start >= 0, chunk.end > chunk.start else { return false }
        guard chunk.start >= finalizedThrough - 0.001 else { return false }
        let overlaps: (StoredChunk) -> Bool = {
            !$0.chunk.isFinal && $0.chunk.start < chunk.end - 0.001 && $0.chunk.end > chunk.start + 0.001
        }
        // Range starts may change during refinement. Overlap, not a raw time
        // value, determines whether this is still the same audio hypothesis.
        let identity = chunks.first(where: overlaps)?.identity ?? nextIdentity
        if identity == nextIdentity { nextIdentity += 1 }
        chunks.removeAll(where: overlaps)
        if chunk.isFinal { finalizedThrough = max(finalizedThrough, chunk.end) }
        if !chunk.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(StoredChunk(chunk: chunk, identity: identity))
        }
        chunks.sort { $0.chunk.start < $1.chunk.start }
        if chunks.count > 16 { chunks.removeFirst(chunks.count - 16) }
        return true
    }

    public mutating func reset() {
        chunks.removeAll()
        finalizedThrough = 0
        nextIdentity = 0
    }
}

private struct StoredChunk: Sendable {
    let chunk: SpeechChunk
    let identity: UInt64
}
