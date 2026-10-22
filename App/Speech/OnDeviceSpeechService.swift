import AVFoundation
import Foundation
import KnowWhereAmICore
import Speech

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
    private var activeID: UUID?
    private var analyzer: SpeechAnalyzer?
    private var capture: CaptureInputSequenceProvider?
    private var installation: AssetInstallationRequest?
    private var audioSessionActive = false
    private var inputContinuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation?
    private var inputTask: Task<Void, Never>?
    private var resultTask: Task<Void, Error>?

    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws {
        guard activeID == nil else { throw SpeechServiceError.alreadyRunning }
        let id = UUID()
        activeID = id
        do {
            await onEvent(.preparing)
            guard SpeechTranscriber.isAvailable else { throw SpeechServiceError.unavailable }
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
                throw SpeechServiceError.englishUnavailable
            }
            try checkActive(id)
            let transcriber = SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: [.audioTimeRange]
            )
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try checkActive(id)
                installation = request
                let progressTask = Task {
                    while !Task.isCancelled {
                        await onEvent(.downloading(max(0, min(1, request.progress.fractionCompleted))))
                        try? await Task.sleep(for: .milliseconds(200))
                    }
                }
                do {
                    try await request.downloadAndInstall()
                    progressTask.cancel()
                } catch {
                    progressTask.cancel()
                    throw error
                }
                installation = nil
            }
            try checkActive(id)
            let authorized = await AVCaptureDevice.requestAccess(for: .audio)
            try checkActive(id)
            guard authorized else { throw SpeechServiceError.microphoneDenied }
            guard let microphone = AVCaptureDevice.default(for: .audio) else { throw SpeechServiceError.noMicrophone }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
            try session.setActive(true)
            audioSessionActive = true
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer
            let capture = try await CaptureInputSequenceProvider.providerWithSession(from: microphone, compatibleWith: [transcriber])
            try checkActive(id)
            self.capture = capture
            try await analyzer.prepareToAnalyze(in: nil)
            try checkActive(id)
            let (inputs, continuation) = AsyncThrowingStream<AnalyzerInput, Error>.makeStream(bufferingPolicy: .bufferingOldest(128))
            inputContinuation = continuation
            let source = capture.analyzerInputs
            inputTask = Task {
                do {
                    for try await input in source {
                        try Task.checkCancellation()
                        switch continuation.yield(input) {
                        case .enqueued: break
                        case .dropped: continuation.finish(throwing: SpeechServiceError.audioBacklog); return
                        case .terminated: return
                        @unknown default: return
                        }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            try await analyzer.start(inputSequence: inputs)
            try checkActive(id)
            capture.captureSession.startRunning()
            guard capture.captureSession.isRunning else { throw SpeechServiceError.captureFailed }
            await onEvent(.listening)

            let results = Task {
                for try await result in transcriber.results {
                    try checkActive(id)
                    await onEvent(.transcript(SpeechChunk(
                        start: result.range.start.seconds,
                        end: result.range.end.seconds,
                        text: String(result.text.characters),
                        isFinal: result.isFinal
                    )))
                }
            }
            resultTask = results
            try await results.value
            if activeID == id { await stop() }
        } catch {
            if activeID == id { await stop() }
            throw error
        }
    }

    func finish() async {
        guard let id = activeID, let analyzer, let results = resultTask else { await stop(); return }
        capture?.captureSession.stopRunning()
        inputContinuation?.finish()
        inputTask?.cancel()
        // End capture first, then drain final results before the report is archived.
        let deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            await self?.stopIfActive(id)
        }
        defer { deadline.cancel() }
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            try await results.value
        } catch { /* Finalized speech remains usable if the final flush is interrupted. */ }
        if activeID == id { await stop() }
    }

    func stop() async {
        activeID = nil
        installation?.progress.cancel()
        installation = nil
        capture?.captureSession.stopRunning()
        capture = nil
        inputContinuation?.finish()
        inputContinuation = nil
        inputTask?.cancel()
        inputTask = nil
        resultTask?.cancel()
        resultTask = nil
        let previousAnalyzer = analyzer
        analyzer = nil
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionActive = false
        }
        await previousAnalyzer?.cancelAndFinishNow()
    }

    private func stopIfActive(_ id: UUID) async {
        if activeID == id { await stop() }
    }

    private func checkActive(_ id: UUID) throws {
        try Task.checkCancellation()
        guard activeID == id else { throw CancellationError() }
    }
}

enum SpeechServiceError: LocalizedError, Equatable {
    case unavailable, englishUnavailable, microphoneDenied, noMicrophone, captureFailed, alreadyRunning, audioBacklog

    var errorDescription: String? {
        switch self {
        case .unavailable: "On-device speech is not available here. Live speech needs a supported physical iPhone."
        case .englishUnavailable: "The English speech model is not available on this device."
        case .microphoneDenied: "Microphone access is turned off. You can enable it in Settings."
        case .noMicrophone: "No microphone is available. Reconnect your microphone and try again."
        case .captureFailed: "The microphone could not start. Check whether another app is using it and try again."
        case .alreadyRunning: "The previous speech session is still stopping. Please try again."
        case .audioBacklog: "Speech processing couldn't keep up with the microphone. Please try again."
        }
    }
}
