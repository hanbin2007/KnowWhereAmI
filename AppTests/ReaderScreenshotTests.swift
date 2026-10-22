import KnowWhereAmICore
import SwiftUI
import UIKit
import XCTest
@testable import KnowWhereAmI

@MainActor
final class ReaderScreenshotTests: XCTestCase {
    func testAccessibilityFindingPositionPreservesTheReadingStage() async throws {
        let root = URL.temporaryDirectory.appending(path: "ReaderScreenshots/\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScriptStore(url: root.appendingPathComponent("reader.json"))
        try store.save(ReaderModel.practice)
        let speech = ScreenshotSpeech()
        let time = ScreenshotTime()
        let model = ReaderModel(store: store, speech: speech, timeSource: { time.seconds })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }
        let controller = UIHostingController(rootView: ReaderView(model: model).dynamicTypeSize(.accessibility5))
        controller.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.rootViewController = controller
        window.makeKeyAndVisible()
        model.toggleListening()
        for _ in 0..<100 {
            if model.phase == .listening { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        time.seconds = 2
        await speech.send(SpeechChunk(start: 0, end: 2, text: "unrelated material nowhere", isFinal: true))
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(model.statusTitle, "Finding position")
        let reader = try XCTUnwrap(findReader(in: window))
        XCTAssertGreaterThan(reader.bounds.height, 100)
        XCTAssertEqual(reader.bounds.width, window.bounds.width, accuracy: 1)
        capture(window, name: "Accessibility finding position - controlled transcript")
        model.pause()
        try await Task.sleep(for: .milliseconds(100))
    }

    func testControlledTranscriptRendersReaderLiveAndSavedReport() async throws {
        let root = URL.temporaryDirectory.appending(path: "ReaderScreenshots/\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScriptStore(url: root.appendingPathComponent("reader.json"))
        try store.save(ReaderModel.practice)
        let speech = ScreenshotSpeech()
        let time = ScreenshotTime()
        let model = ReaderModel(store: store, speech: speech, timeSource: { time.seconds })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }
        window.rootViewController = UIHostingController(rootView: ReaderView(model: model))
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(400))
        capture(window, name: "Rehearsal ready")

        model.setMode(.live)
        model.selectWord(52)
        model.stageLocked = true
        try await Task.sleep(for: .milliseconds(600))
        let lockedReader = try XCTUnwrap(findReader(in: window))
        XCTAssertEqual(lockedReader.bounds.width, window.bounds.width, accuracy: 1,
                       "Locking must not change the reader's intrinsic size")
        capture(window, name: "Live rescue position")
        model.setMode(.rehearsal)
        model.restart()
        model.toggleListening()
        for _ in 0..<100 {
            if model.phase == .listening { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.phase, .listening)
        time.seconds = 2.5
        await speech.send(SpeechChunk(start: 0, end: 2.5, text: "Every good idea starts a question", isFinal: true))
        try await Task.sleep(for: .milliseconds(600))
        capture(window, name: "Controlled transcript with one omission")
        model.finishRehearsal()
        for _ in 0..<100 {
            if model.phase == .finished { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.history.first?.statistics.missedWords, 1)
        XCTAssertEqual(model.history.first?.statistics.wordsPerMinute, 144)
        try await Task.sleep(for: .milliseconds(1800))
        capture(window, name: "Saved rehearsal report - controlled transcript")
        model.presentedReport = nil
        try await Task.sleep(for: .milliseconds(400))
        let record = try XCTUnwrap(model.history.first)
        let accessibleReport = UIHostingController(rootView: NavigationStack {
            RehearsalReportView(record: record)
        }.dynamicTypeSize(.accessibility5))
        accessibleReport.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.rootViewController = accessibleReport
        try await Task.sleep(for: .milliseconds(1800))
        capture(window, name: "Accessibility visual rehearsal report - controlled transcript")
    }

    private func capture(_ window: UIWindow, name: String) {
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func findReader(in view: UIView) -> UITextView? {
        if let reader = view as? UITextView, reader.accessibilityIdentifier == "scriptReader" { return reader }
        return view.subviews.lazy.compactMap(findReader).first
    }
}

@MainActor
private final class ScreenshotTime { var seconds: Double = 0 }

private actor ScreenshotSpeech: SpeechRecognizing {
    private var callback: (@Sendable (SpeechEvent) async -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?
    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws {
        callback = onEvent
        await onEvent(.listening)
        await withCheckedContinuation { continuation = $0 }
    }
    func send(_ chunk: SpeechChunk) async { await callback?(.transcript(chunk)) }
    func stop() async { continuation?.resume(); continuation = nil }
}
