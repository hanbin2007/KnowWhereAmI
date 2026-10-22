// CI-only replacement for App/Speech/OnDeviceSpeechService.swift.
// Hosted runners ship an older SDK without CaptureInputSequenceProvider, so the
// screenshot workflow swaps this in. It never captures audio.
import Foundation
import KnowWhereAmICore

enum SpeechEvent: Sendable {
    case preparing
    case downloading(Double)
    case listening
    case transcript(SpeechChunk)
}

protocol SpeechRecognizing: Sendable {
    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws
    func stop() async
    func finish() async
}

extension SpeechRecognizing {
    func finish() async { await stop() }
}

actor OnDeviceSpeechService: SpeechRecognizing {
    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws {
        await onEvent(.preparing)
        throw SpeechServiceError.unavailable
    }
    func stop() async {}
}

enum SpeechServiceError: LocalizedError, Equatable {
    case unavailable, englishUnavailable, microphoneDenied, noMicrophone, captureFailed, alreadyRunning, audioBacklog
    var errorDescription: String? { "On-device speech is not available in this CI build." }
}
