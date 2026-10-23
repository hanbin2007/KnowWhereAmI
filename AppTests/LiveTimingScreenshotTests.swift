import KnowWhereAmICore
import SwiftUI
import UIKit
import XCTest
@testable import KnowWhereAmI

@MainActor
final class LiveTimingScreenshotTests: XCTestCase {
    func testLiveTimerRendersItsPaceWarningsInLightDarkAndLargeText() async throws {
        let (model, speech, time, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let window = try host(model)
        defer { window.isHidden = true; model.pause() }
        window.overrideUserInterfaceStyle = .light
        try await Task.sleep(for: .milliseconds(400))
        capture(window, name: "Live timer - ready")
        model.toggleListening()
        for _ in 0..<100 {
            if model.phase == .listening { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        for count in stride(from: 6, through: 60, by: 6) {
            time.seconds = Double(count) / 2
            let words = model.document.words.prefix(count).map(\.text).joined(separator: " ")
            await speech.send(SpeechChunk(start: 0, end: time.seconds, text: words, isFinal: false))
        }
        XCTAssertEqual(model.liveTimer.state, .onTrack)
        try await Task.sleep(for: .milliseconds(1_100))
        XCTAssertEqual(model.liveTimer.state, .onTrack)
        capture(window, name: "Live timer - on track")
        XCTAssertTrue(model.setLiveTimeLimit(60))
        XCTAssertEqual(model.liveTimer.state, .behind)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(model.liveTimer.state, .behind)
        capture(window, name: "Live timer - behind pace light")
        window.overrideUserInterfaceStyle = .dark
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(model.liveTimer.state, .behind)
        capture(window, name: "Live timer - behind pace dark")
        time.seconds = 61
        try await Task.sleep(for: .milliseconds(1_100))
        XCTAssertEqual(model.liveTimer.clockText, "+0:01")
        capture(window, name: "Live timer - overtime dark")
        let controller = UIHostingController(rootView: ReaderView(model: model).dynamicTypeSize(.accessibility5))
        controller.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .light
        try await Task.sleep(for: .milliseconds(700))
        capture(window, name: "Live timer - accessibility")
    }

    func testLiveTimerRemainsVisibleInACompactLargeTextLayout() async throws {
        let (model, _, _, root) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let window = try host(model)
        defer { window.isHidden = true; model.pause() }
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.rootViewController = UIHostingController(rootView: ReaderView(model: model).dynamicTypeSize(.accessibility5))
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(window.bounds.width, 320, accuracy: 1)
        capture(window, name: "Live timer - compact 320x568 accessibility")
        XCTAssertTrue(model.setLiveTimeLimit(3_600))
        try await Task.sleep(for: .milliseconds(1_100))
        capture(window, name: "Live timer - compact one hour accessibility")
        window.frame = CGRect(x: 0, y: 0, width: 874, height: 402)
        window.rootViewController = UIHostingController(rootView: ReaderView(model: model))
        try await Task.sleep(for: .milliseconds(700))
        capture(window, name: "Live timer - landscape")
    }

    private func fixture() throws -> (ReaderModel, TimerScreenshotSpeech, TimerScreenshotTime, URL) {
        let root = URL.temporaryDirectory.appending(path: "LiveTimerScreenshots/\(UUID().uuidString)")
        let store = ScriptStore(url: root.appendingPathComponent("reader.json"))
        try store.save(ReaderModel.practice)
        let speech = TimerScreenshotSpeech()
        let time = TimerScreenshotTime()
        let model = ReaderModel(store: store, speech: speech, timeSource: { time.seconds })
        model.setMode(.live)
        return (model, speech, time, root)
    }

    private func host(_ model: ReaderModel) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: ReaderView(model: model))
        window.makeKeyAndVisible()
        return window
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
}

@MainActor private final class TimerScreenshotTime { var seconds: Double = 0 }

private actor TimerScreenshotSpeech: SpeechRecognizing {
    private var callback: (@Sendable (SpeechEvent) async -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?
    func run(onEvent: @escaping @Sendable (SpeechEvent) async -> Void) async throws {
        callback = onEvent
        await onEvent(.listening)
        await withCheckedContinuation { continuation = $0 }
    }
    func send(_ chunk: SpeechChunk) async { await callback?(.transcript(chunk)) }
    func stop() async { callback = nil; continuation?.resume(); continuation = nil }
}
