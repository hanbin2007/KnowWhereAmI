import KnowWhereAmICore
import Observation
import SwiftUI
import UIKit
import XCTest
@testable import KnowWhereAmI

@MainActor
final class ReaderFocusTests: XCTestCase {
    func testEveryLineIncludingFirstAndLastStaysInTheFocusLane() async throws {
        let harness = FocusHarness()
        let window = try show(harness)
        defer { window.isHidden = true }
        let reader = try await findReader(in: window)
        for word in [0, 35, 75, 120, 199] {
            harness.cursor = word
            try await Task.sleep(for: .milliseconds(500))
            reader.layoutIfNeeded()
            let y = lineMidY(in: reader, document: harness.document, word: word) - reader.contentOffset.y
            XCTAssertEqual(y, reader.bounds.height * 0.34, accuracy: 2, "Word \(word) lost focus")
        }
    }

    func testViewportResizeRefocusesWithoutNeedingAnotherRecognizedWord() async throws {
        let harness = FocusHarness()
        harness.cursor = 100
        let window = try show(harness)
        defer { window.isHidden = true }
        let reader = try await findReader(in: window)
        try await Task.sleep(for: .milliseconds(500))
        let before = lineMidY(in: reader, document: harness.document, word: 100) - reader.contentOffset.y
        XCTAssertEqual(before, reader.bounds.height * 0.34, accuracy: 2, "Initial focus must work before resizing")
        harness.height = 300
        try await Task.sleep(for: .milliseconds(500))
        reader.layoutIfNeeded()
        let y = lineMidY(in: reader, document: harness.document, word: 100) - reader.contentOffset.y
        XCTAssertEqual(y, reader.bounds.height * 0.34, accuracy: 2,
                       "before=\(before), offset=\(reader.contentOffset), content=\(reader.contentSize), insets=\(reader.contentInset), window=\(reader.window != nil), same=\(descend(window) === reader)")
    }

    func testCursorUpdatesDoNotReplaceTheWholeManuscript() async throws {
        let harness = FocusHarness()
        let window = try show(harness)
        defer { window.isHidden = true }
        let reader = try await findReader(in: window)
        let probe = TextEditProbe()
        reader.textStorage.delegate = probe
        for word in 1...12 {
            harness.cursor = word
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTAssertEqual(probe.characterEdits, 0, "Changing a word highlight must not replace text/layout")
    }

    func testHighlightReturnsWhenTheSameWordIsRestoredAfterReset() async throws {
        let harness = FocusHarness()
        let window = try show(harness)
        defer { window.isHidden = true }
        let reader = try await findReader(in: window)
        let highlight = try XCTUnwrap(reader.subviews.first { $0.accessibilityIdentifier == "currentWordHighlight" })
        harness.cursor = nil
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(highlight.alpha, 0)
        harness.cursor = 0
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertGreaterThan(highlight.alpha, 0.9)
    }

    func testManualPeekIsNotInterruptedAndExplicitRecenterStillWorks() async throws {
        let harness = FocusHarness()
        let window = try show(harness)
        defer { window.isHidden = true }
        let reader = try await findReader(in: window)
        harness.follows = false
        try await Task.sleep(for: .milliseconds(50))
        reader.setContentOffset(CGPoint(x: 0, y: 350), animated: false)
        harness.cursor = 150
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(reader.contentOffset.y, 350, accuracy: 1)
        harness.recenter += 1
        try await Task.sleep(for: .milliseconds(500))
        let y = lineMidY(in: reader, document: harness.document, word: 150) - reader.contentOffset.y
        XCTAssertEqual(y, reader.bounds.height * 0.34, accuracy: 2)
    }

    func testReducedMotionPlacesNewFocusImmediately() throws {
        let harness = FocusHarness()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true }
        let controller = UIViewController()
        window.rootViewController = controller
        let reader = ReaderTextSurface()
        reader.frame = CGRect(x: 0, y: 0, width: 402, height: 500)
        controller.view.addSubview(reader)
        window.makeKeyAndVisible()
        for word in [0, 120] {
            reader.configure(document: harness.document, cursor: word, tentative: false, pointSize: 26,
                             dark: false, typeSize: .large, follows: true, recenter: 0,
                             reducedMotion: true, allowsInteraction: true)
            reader.layoutIfNeeded()
            let y = lineMidY(in: reader, document: harness.document, word: word) - reader.contentOffset.y
            XCTAssertEqual(y, reader.bounds.height * 0.34, accuracy: 2)
        }
    }

    private func show(_ harness: FocusHarness) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: FocusHarnessView(harness: harness))
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    private func findReader(in view: UIView) async throws -> UITextView {
        for _ in 0..<30 {
            if let reader = descend(view), reader.bounds.height > 0, !reader.text.isEmpty {
                try await Task.sleep(for: .milliseconds(80))
                return reader
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw NSError(domain: "ReaderFocusTests", code: 1)
    }

    private func descend(_ view: UIView) -> UITextView? {
        if let text = view as? UITextView { return text }
        return view.subviews.lazy.compactMap(descend).first
    }

    private func lineMidY(in reader: UITextView, document: ScriptDocument, word: Int) -> CGFloat {
        let glyph = reader.layoutManager.glyphIndexForCharacter(at: document.words[word].range.location)
        return reader.layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).midY + reader.textContainerInset.top
    }
}

@MainActor @Observable
private final class FocusHarness {
    let document = ScriptDocument(text: (0..<200).map { "word\($0)" }.joined(separator: " "))
    var cursor: Int? = 0
    var follows = true
    var recenter = 0
    var height: CGFloat = 500
}

private struct FocusHarnessView: View {
    let harness: FocusHarness
    var body: some View {
        ScriptTextView(document: harness.document, cursor: harness.cursor, isTentative: false,
                       fontSize: 26, followsPosition: harness.follows, recenterID: harness.recenter,
                       onSelect: { _ in }, onManualScroll: {})
            .frame(height: harness.height)
    }
}

private final class TextEditProbe: NSObject, NSTextStorageDelegate {
    var characterEdits = 0
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        if editedMask.contains(.editedCharacters) { characterEdits += 1 }
    }
}
