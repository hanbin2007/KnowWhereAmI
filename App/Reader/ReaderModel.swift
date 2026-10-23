import Foundation
import KnowWhereAmICore
import Observation

enum ReaderMode: String, CaseIterable, Identifiable {
    case rehearsal, live
    var id: String { rawValue }
    var title: String { self == .rehearsal ? "Rehearsal" : "Live" }
}

enum ReaderPhase: Equatable {
    case ready, preparing, downloading(Double), listening, finishing, stopping, paused, finished
    var isActive: Bool {
        switch self {
        case .preparing, .downloading, .listening: true
        default: false
        }
    }
    var title: String {
        switch self {
        case .ready: "Ready"
        case .preparing: "Preparing speech"
        case .downloading: "Downloading English"
        case .listening: "Listening"
        case .finishing: "Finishing rehearsal"
        case .stopping: "Stopping"
        case .paused: "Paused"
        case .finished: "Finished"
        }
    }
}

struct ReaderAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var offersSettings = false
}

@MainActor @Observable
final class ReaderModel {
    private(set) var library: ScriptLibrary
    private(set) var document: ScriptDocument
    private(set) var paragraphStarts: [Int]
    private(set) var phase: ReaderPhase = .ready
    private(set) var mode = ReaderMode.rehearsal
    private(set) var cursor: Int?
    private(set) var confirmedCursor: Int?
    private(set) var heard = ""
    private(set) var isFindingPosition = false
    var followsPosition = true
    private(set) var recenterID = 0
    var stageLocked = false
    var alert: ReaderAlert?
    var presentedReport: RehearsalRecord?
    private let rehearsal: RehearsalSession

    @ObservationIgnored private var tracker: ScriptTracker
    @ObservationIgnored private var buffer = TranscriptBuffer()
    @ObservationIgnored private let speech: any SpeechRecognizing
    @ObservationIgnored private let libraryStore: ScriptLibraryStore
    @ObservationIgnored private var libraryLoadError: String?
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var nextStoppedPhase = ReaderPhase.paused
    @ObservationIgnored private var resumeAfterSeek = false

    init(store: ScriptStore? = nil, speech: any SpeechRecognizing = OnDeviceSpeechService(),
         timeSource: (@MainActor () -> Double)? = nil) {
        let legacyURL = store?.url ?? Self.storageURL
        let libraryStore = ScriptLibraryStore(url: legacyURL.deletingPathExtension().appendingPathExtension("library.json"), legacyURL: legacyURL)
        self.libraryStore = libraryStore
        self.speech = speech
        let origin = ContinuousClock.now
        let now: @MainActor () -> Double = timeSource ?? {
            let parts = origin.duration(to: .now).components
            return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        }
        let practice = Manuscript(content: Self.practice)
        var initial = ScriptLibrary(manuscripts: [practice], selectedID: practice.id)
        var failure: String?
        do {
            if let restored = try libraryStore.load() { initial = restored }
            else { try libraryStore.save(initial) }
        } catch { failure = error.localizedDescription }
        library = initial
        libraryLoadError = failure
        let document = ScriptDocument(text: initial.selected?.content.text ?? "")
        self.document = document
        paragraphStarts = Self.paragraphStarts(in: document)
        tracker = ScriptTracker(document: document)
        followsPosition = initial.selected?.content.followsPosition ?? true
        rehearsal = RehearsalSession(document: document,
            store: RehearsalHistoryStore(url: legacyURL.deletingPathExtension().appendingPathExtension("rehearsals.json")), now: now)
        if let failure {
            alert = ReaderAlert(title: "Couldn't open saved scripts", message: "Your original files were left unchanged. \(failure)")
        } else if let error = rehearsal.loadError {
            alert = ReaderAlert(title: "Couldn't open rehearsals", message: "Your rehearsal history was left unchanged. \(error)")
        }
    }

    var saved: SavedReaderState { library.selected?.content ?? SavedReaderState(title: "Untitled script", text: "") }
    var history: [RehearsalRecord] { rehearsal.history }
    var elapsedSeconds: Double { rehearsal.elapsed }
    var statistics: RehearsalStatistics { rehearsal.statistics }
    var hasRehearsal: Bool { rehearsal.hasStarted }
    var latestReport: RehearsalRecord? { history.first { $0.manuscriptID == library.selectedID } }
    var position: Int { cursor.map { $0 + 1 } ?? 0 }
    var progress: Double { document.words.isEmpty ? 0 : Double(position) / Double(document.words.count) }
    var isTentative: Bool { cursor != nil && cursor != confirmedCursor }
    var statusTitle: String {
        if phase == .listening, isFindingPosition { return "Finding position" }
        if phase == .listening, mode == .live, position == document.words.count { return "At end" }
        return phase.title
    }

    func toggleListening() {
        if phase.isActive { pause(); return }
        guard phase != .stopping, phase != .finishing, !document.words.isEmpty else { return }
        if phase == .finished { restart() }
        guard phase != .stopping else { return }
        startListening()
    }

    private func startListening() {
        tracker.beginSession()
        buffer.reset()
        heard = ""
        isFindingPosition = false
        followsPosition = saved.followsPosition
        recenterID += 1
        generation = UUID()
        let id = generation
        phase = .preparing
        work = Task { [weak self, speech] in
            do {
                try await speech.run { [weak self] event in await self?.receive(event, generation: id) }
                guard let self, self.generation == id, self.phase != .finishing else { return }
                self.rehearsal.pause()
                self.phase = .paused
            } catch is CancellationError {
                // The explicit stop path owns the next visible state.
            } catch {
                guard let self, self.generation == id, self.phase != .finishing else { return }
                self.rehearsal.pause()
                self.phase = .paused
                self.alert = ReaderAlert(title: "Couldn't listen", message: error.localizedDescription,
                    offersSettings: (error as? SpeechServiceError) == .microphoneDenied)
            }
        }
    }

    func pause() {
        resumeAfterSeek = false
        cancelPeek()
        rehearsal.pause()
        guard phase.isActive || phase == .finishing else { return }
        stop(next: .paused)
    }

    func restart() {
        pause()
        guard archiveRehearsal() else { return }
        stop(next: .ready)
        rehearsal.reset(document: document)
        clearPosition()
    }

    func setMode(_ next: ReaderMode) {
        guard mode != next else { return }
        pause()
        guard archiveRehearsal() else { return }
        mode = next
        stageLocked = false
        rehearsal.reset(document: document, startWord: cursor ?? 0)
        recenter()
    }

    func selectWord(_ index: Int) {
        guard document.words.indices.contains(index) else { return }
        let shouldResume = mode == .live && phase == .listening
        resumeAfterSeek = shouldResume
        cancelPeek()
        stop(next: .paused)
        tracker.select(wordIndex: index)
        if mode == .rehearsal { rehearsal.setAnchor(index) }
        cursor = index
        confirmedCursor = index
        buffer.reset()
        heard = ""
        isFindingPosition = false
        recenter()
    }

    func jumpParagraph(_ direction: Int) {
        guard canJumpParagraph(direction) else { return }
        let paragraph = currentParagraph
        selectWord(paragraphStarts[paragraph + (direction > 0 ? 1 : -1)])
    }

    func canJumpParagraph(_ direction: Int) -> Bool {
        guard direction != 0, !paragraphStarts.isEmpty else { return false }
        return direction > 0 ? currentParagraph < paragraphStarts.count - 1 : currentParagraph > 0
    }

    private var currentParagraph: Int { paragraphStarts.lastIndex(where: { $0 <= (cursor ?? 0) }) ?? 0 }

    private static func paragraphStarts(in document: ScriptDocument) -> [Int] {
        var starts: [Int] = []
        let source = document.text
        let words = document.words
        var index = 0
        source.enumerateSubstrings(in: source.startIndex..<source.endIndex, options: .byParagraphs) { _, range, _, _ in
            let span = NSRange(range, in: source)
            while index < words.count, words[index].range.location < span.location { index += 1 }
            if index < words.count, NSLocationInRange(words[index].range.location, span) { starts.append(index) }
        }
        return starts
    }

    func recenter() {
        cancelPeek()
        followsPosition = saved.followsPosition
        recenterID += 1
    }

    func beginManualScroll() {
        cancelPeek()
        followsPosition = false
    }

    func endManualScroll() {
        guard phase == .listening, saved.followsPosition else { return }
        let id = generation
        peekTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
            guard let self, self.generation == id, self.phase == .listening, self.saved.followsPosition else { return }
            self.recenter()
        }
    }

    func finishRehearsal(presentReport: Bool = true) {
        guard mode == .rehearsal, rehearsal.hasStarted, phase != .finishing else { return }
        resumeAfterSeek = false
        cancelPeek()
        rehearsal.pause()
        if phase != .listening {
            if archiveRehearsal(presentReport: presentReport, allowEmpty: true) { phase = .finished }
            return
        }
        let id = generation
        phase = .finishing
        Task { [weak self, speech] in
            await speech.finish()
            guard let self, self.generation == id else { return }
            self.work?.cancel()
            self.work = nil
            self.generation = UUID()
            self.phase = self.archiveRehearsal(presentReport: presentReport, allowEmpty: true) ? .finished : .paused
        }
    }

    func deleteRehearsal(_ id: UUID) -> Bool {
        do { try rehearsal.deleteRecord(id); return true }
        catch { alert = ReaderAlert(title: "Couldn't delete rehearsal", message: error.localizedDescription); return false }
    }

    func showReport(_ record: RehearsalRecord) {
        pause()
        presentedReport = record
    }

    func prepareScriptTransition() -> Bool {
        pause()
        return archiveRehearsal()
    }

    func commitLibrary(_ next: ScriptLibrary, reloadSelection: Bool = false) -> Bool {
        do {
            if let libraryLoadError { throw SessionStorageError.unavailable(libraryLoadError) }
            try libraryStore.save(next)
            library = next
            if reloadSelection {
                stop(next: .ready)
                document = ScriptDocument(text: saved.text)
                paragraphStarts = Self.paragraphStarts(in: document)
                tracker = ScriptTracker(document: document)
                rehearsal.reset(document: document)
                clearPosition()
                followsPosition = saved.followsPosition
            }
            return true
        } catch {
            alert = ReaderAlert(title: "Couldn't save scripts", message: error.localizedDescription)
            return false
        }
    }

    private func archiveRehearsal(presentReport: Bool = false, allowEmpty: Bool = false) -> Bool {
        guard mode == .rehearsal else { return true }
        do {
            let record = try rehearsal.archive(allowEmpty: allowEmpty)
            if presentReport { presentedReport = record }
            return true
        } catch {
            alert = ReaderAlert(title: "Couldn't save rehearsal", message: error.localizedDescription)
            return false
        }
    }

    private func clearPosition() {
        tracker.reset()
        buffer.reset()
        cursor = nil
        confirmedCursor = nil
        heard = ""
        isFindingPosition = false
        recenter()
    }

    private func cancelPeek() { peekTask?.cancel(); peekTask = nil }

    private func stop(next: ReaderPhase) {
        rehearsal.pause()
        nextStoppedPhase = next
        guard phase.isActive || phase == .finishing else {
            if phase != .stopping { phase = next }
            return
        }
        generation = UUID()
        let id = generation
        work?.cancel()
        work = nil
        phase = .stopping
        Task { [weak self, speech] in
            await speech.stop()
            guard let self, self.generation == id else { return }
            self.phase = self.nextStoppedPhase
            if self.resumeAfterSeek, self.mode == .live, !self.document.words.isEmpty {
                self.resumeAfterSeek = false
                self.startListening()
            }
        }
    }

    private func receive(_ event: SpeechEvent, generation id: UUID) {
        guard generation == id, phase.isActive || phase == .finishing else { return }
        switch event {
        case .preparing:
            if phase != .finishing { phase = .preparing }
        case .downloading(let progress):
            switch phase {
            case .preparing, .downloading: phase = .downloading(progress)
            default: break
            }
        case .listening:
            guard phase != .finishing else { return }
            phase = .listening
            if mode == .rehearsal, let manuscript = library.selected { rehearsal.resume(manuscript: manuscript) }
        case .transcript(let chunk):
            guard phase == .listening || phase == .finishing, buffer.ingest(chunk) else { return }
            heard = String(buffer.text.suffix(240))
            var update: TrackingUpdate
            if chunk.isFinal, !chunk.text.isEmpty {
                update = tracker.consume(buffer.finalizedText, isFinal: true, hypothesisID: buffer.finalizedHypothesisID,
                                         segmentText: buffer.finalizedSegmentText, audioRange: buffer.finalizedSegmentAudioRange)
                if mode == .rehearsal { rehearsal.recordFinal(text: chunk.text, evidence: update.evidence) }
                if buffer.hasTentativeText {
                    update = tracker.consume(buffer.text, isFinal: false, hypothesisID: buffer.hypothesisID,
                                             segmentText: buffer.segmentText, audioRange: buffer.segmentAudioRange)
                }
            } else if chunk.text.isEmpty, !buffer.hasTentativeText {
                update = tracker.revokeTentative()
            } else {
                update = tracker.consume(buffer.text, isFinal: false, hypothesisID: buffer.hypothesisID,
                                         segmentText: buffer.segmentText, audioRange: buffer.segmentAudioRange)
            }
            cursor = update.wordIndex
            confirmedCursor = update.confirmedWordIndex
            isFindingPosition = !update.isMatched && !chunk.text.isEmpty
            if update.isFinished, mode == .rehearsal, phase != .finishing { finishRehearsal() }
        }
    }

    private static var storageURL: URL {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["KNOWWHEREAMI_TEST_STORE"], let id = UUID(uuidString: value) {
            return URL.cachesDirectory.appending(path: "UITestScripts/\(id.uuidString).json")
        }
        #endif
        return URL.applicationSupportDirectory.appending(path: "KnowWhereAmI/reader.json")
    }

    static let practice = SavedReaderState(title: "Practice script", text: """
    Every good idea starts with a question.

    What would happen if we paid a little more attention? Not to the loudest voice in the room, but to the small things we usually pass by. A conversation with a friend. A problem that keeps coming back. A moment when something almost works.

    Progress doesn't always arrive as a sudden breakthrough. More often, it begins with a small step, followed by another. We try something. We notice what changes. And then we try again.

    Today, I want to talk about those small steps. The choices that help us move from an interesting thought to something real. We don't need to have every answer before we begin. We need a clear direction, a little patience, and the courage to keep learning.

    So let's start with one question: what is the next small thing we can do better?
    """)
}
