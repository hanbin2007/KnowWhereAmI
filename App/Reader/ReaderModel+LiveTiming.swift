import Foundation
import KnowWhereAmICore

extension ReaderModel {
    var liveTimer: LiveTimingSnapshot {
        let consumed = cursor.map { $0 + (cursorIsSelection ? 0 : 1) } ?? 0
        let remaining = document.words.isEmpty ? nil : max(0, document.words.count - consumed)
        return liveSession.snapshot(remainingWords: remaining, positionReliable: !isFindingPosition)
    }

    @discardableResult
    func setLiveTimeLimit(_ seconds: Int) -> Bool {
        guard LiveTimingSession.allowedLimits.contains(seconds),
              let index = library.manuscripts.firstIndex(where: { $0.id == library.selectedID }) else { return false }
        var next = library
        next.manuscripts[index].content.liveTimeLimitSeconds = seconds
        guard commitLibrary(next) else { return false }
        return true
    }

    func startLiveCountdown() {
        guard mode == .live else { return }
        liveSession.start()
    }

    func restartLiveCountdown() {
        guard mode == .live else { return }
        liveSession.restart()
    }
}
