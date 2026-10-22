import Foundation
import KnowWhereAmICore
import Observation

@MainActor @Observable
final class RehearsalSession {
    private var accumulator: RehearsalAccumulator
    private var accumulated: Double = 0
    private var activeSince: Double?
    private var startedAt: Date?
    private var manuscript: Manuscript?
    private var recordID = UUID()
    private var lastArchive: RehearsalRecord?
    private(set) var history: [RehearsalRecord] = []
    private(set) var loadError: String?
    @ObservationIgnored private let store: RehearsalHistoryStore
    @ObservationIgnored private let now: @MainActor () -> Double

    init(document: ScriptDocument, store: RehearsalHistoryStore, now: @escaping @MainActor () -> Double) {
        accumulator = RehearsalAccumulator(document: document)
        self.store = store
        self.now = now
        do { history = try store.load().sorted { $0.endedAt > $1.endedAt } }
        catch { loadError = error.localizedDescription }
    }

    var hasStarted: Bool { startedAt != nil }
    var hasSpoken: Bool { statistics.spokenWords > 0 }
    var elapsed: Double { accumulated + (activeSince.map { max(0, now() - $0) } ?? 0) }
    var statistics: RehearsalStatistics { accumulator.snapshot(elapsedSeconds: elapsed) }

    func resume(manuscript: Manuscript) {
        if startedAt == nil { startedAt = Date(); self.manuscript = manuscript }
        if activeSince == nil { activeSince = now() }
    }

    func pause() {
        if let activeSince { accumulated += max(0, now() - activeSince) }
        activeSince = nil
    }

    func recordFinal(text: String, evidence: AlignmentEvidence?) {
        guard hasStarted else { return }
        accumulator.recordFinal(text: text, evidence: evidence)
    }

    func setAnchor(_ word: Int) { accumulator.setAnchor(wordIndex: word) }

    func reset(document: ScriptDocument, startWord: Int = 0) {
        accumulator = RehearsalAccumulator(document: document, startWord: startWord)
        accumulated = 0
        activeSince = nil
        startedAt = nil
        manuscript = nil
        recordID = UUID()
        lastArchive = nil
    }

    func archive(allowEmpty: Bool = false) throws -> RehearsalRecord? {
        pause()
        if let lastArchive, lastArchive.statistics == statistics {
            return history.first { $0.id == recordID }
        }
        guard let manuscript, let startedAt, hasSpoken || allowEmpty else { return nil }
        if let loadError { throw SessionStorageError.unavailable(loadError) }
        let record = RehearsalRecord(id: recordID, manuscriptID: manuscript.id, title: manuscript.content.title,
                                     scriptText: manuscript.content.text, startedAt: startedAt,
                                     endedAt: Date(), statistics: statistics)
        let next = [record] + history.filter { $0.id != recordID }
        try store.save(next)
        history = next
        lastArchive = record
        return record
    }

    func deleteRecord(_ id: UUID) throws {
        if let loadError { throw SessionStorageError.unavailable(loadError) }
        let next = history.filter { $0.id != id }
        try store.save(next)
        history = next
    }
}

enum SessionStorageError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self {
        case .unavailable(let detail): "The saved file could not be read and has been left unchanged. \(detail)"
        }
    }
}
