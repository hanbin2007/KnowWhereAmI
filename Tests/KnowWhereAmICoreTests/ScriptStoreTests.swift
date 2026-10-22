import Foundation
import Testing
@testable import KnowWhereAmICore

@Test func manuscriptAndReaderSizeSurviveRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ScriptStore(url: directory.appendingPathComponent("script.json"))
    #expect(try store.load() == nil)
    let original = SavedReaderState(title: "My presentation", text: "Hello, everyone.\nA new paragraph.", fontSize: 30, followsPosition: false)
    try store.save(original)
    #expect(try ScriptStore(url: store.url).load() == original)
}

@Test func olderSavedScriptsKeepWorkingWhenNewReaderSettingsAreAdded() throws {
    let data = Data(#"{"title":"Original","text":"Keep my words.","fontSize":26}"#.utf8)
    let restored = try JSONDecoder().decode(SavedReaderState.self, from: data)
    #expect(restored.title == "Original")
    #expect(restored.followsPosition)
}

@Test func invalidSaveDoesNotDestroyLastGoodManuscript() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ScriptStore(url: directory.appendingPathComponent("script.json"))
    let good = SavedReaderState(title: "Saved", text: "Keep these words.")
    try store.save(good)
    #expect(throws: (any Error).self) {
        try store.save(SavedReaderState(title: "Bad", text: "Too large", fontSize: .nan))
    }
    #expect(try store.load() == good)
}

@Test func malformedStoredDataIsReportedAndNotReplaced() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("script.json")
    let original = Data("not valid JSON".utf8)
    try original.write(to: url)
    let store = ScriptStore(url: url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: url) == original)
}
