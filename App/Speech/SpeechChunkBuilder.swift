import CoreMedia
import Foundation
import KnowWhereAmICore
import Speech

enum SpeechChunkBuilder {
    static func make(text: AttributedString, range: CMTimeRange, isFinal: Bool) -> SpeechChunk {
        let timings = text.runs.compactMap { run -> SpeechWordTiming? in
            guard let time = run.audioTimeRange else { return nil }
            let count = ScriptDocument.wordCount(in: String(text[run.range].characters))
            guard count > 0 else { return nil }
            return SpeechWordTiming(start: time.start.seconds, end: time.end.seconds, wordCount: count)
        }
        return SpeechChunk(start: range.start.seconds, end: range.end.seconds,
                           text: String(text.characters), isFinal: isFinal, wordTimings: timings)
    }
}
