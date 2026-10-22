import Foundation
import Testing
@testable import KnowWhereAmICore

@Test func librarySelectionEditsAndReaderPreferencesSurviveRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ScriptLibraryStore(url: directory.appendingPathComponent("library.json"))
    let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let first = Manuscript(
        id: firstID,
        content: SavedReaderState(title: "First", text: "First words.", fontSize: 20, followsPosition: false),
        createdAt: Date(timeIntervalSince1970: 100),
        modifiedAt: Date(timeIntervalSince1970: 200)
    )
    let second = Manuscript(
        id: secondID,
        content: SavedReaderState(title: "Second", text: "Second words.", fontSize: 38, followsPosition: true),
        createdAt: Date(timeIntervalSince1970: 300),
        modifiedAt: Date(timeIntervalSince1970: 400)
    )
    try store.save(ScriptLibrary(manuscripts: [first, second], selectedID: firstID))

    var restored = try #require(try ScriptLibraryStore(url: store.url).load())
    #expect(restored.selected == first)
    restored.selectedID = secondID
    restored.manuscripts[1].content.text = "Revised second words."
    restored.manuscripts[1].modifiedAt = Date(timeIntervalSince1970: 500)
    try store.save(restored)

    let relaunched = try #require(try ScriptLibraryStore(url: store.url).load())
    #expect(relaunched == restored)
    #expect(relaunched.manuscripts.map(\.id) == [firstID, secondID])
    #expect(relaunched.manuscripts[0] == first)
    #expect(relaunched.selected?.content.text == "Revised second words.")
    #expect(relaunched.selected?.content.fontSize == 38)
    #expect(relaunched.selected?.content.followsPosition == true)
    #expect(relaunched.selected?.createdAt == Date(timeIntervalSince1970: 300))
    #expect(relaunched.selected?.modifiedAt == Date(timeIntervalSince1970: 500))
}

@Test func validLegacyScriptMigratesOnceWithoutChangingLegacyBytes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacyURL = directory.appendingPathComponent("script.json")
    let legacy = SavedReaderState(title: "Old presentation", text: "Keep every word.\nAnd this line.", fontSize: 32, followsPosition: false)
    try ScriptStore(url: legacyURL).save(legacy)
    let originalBytes = try Data(contentsOf: legacyURL)
    let store = ScriptLibraryStore(url: directory.appendingPathComponent("library.json"), legacyURL: legacyURL)
    let beforeMigration = Date()

    let migrated = try #require(try store.load())

    #expect(migrated.manuscripts.count == 1)
    let selected = try #require(migrated.selected)
    #expect(selected.content == legacy)
    #expect(selected.createdAt >= beforeMigration)
    #expect(selected.modifiedAt >= beforeMigration)
    #expect(selected.createdAt <= Date())
    #expect(selected.modifiedAt <= Date())
    #expect(migrated.selectedID == selected.id)
    #expect(try Data(contentsOf: legacyURL) == originalBytes)
    #expect(try ScriptLibraryStore(url: store.url).load() == migrated)
    #expect(try store.load() == migrated)
    #expect(try Data(contentsOf: legacyURL) == originalBytes)
}

@Test func primaryLibraryIsAuthoritativeWhenLegacyStillExists() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacyURL = directory.appendingPathComponent("script.json")
    let store = ScriptLibraryStore(url: directory.appendingPathComponent("library.json"), legacyURL: legacyURL)
    let current = Manuscript(content: SavedReaderState(title: "Current", text: "New words."))
    let library = ScriptLibrary(manuscripts: [current], selectedID: current.id)
    try store.save(library)
    let corruptLegacyBytes = Data("broken legacy JSON".utf8)
    try corruptLegacyBytes.write(to: legacyURL)

    #expect(try store.load() == library)
    #expect(try Data(contentsOf: legacyURL) == corruptLegacyBytes)
}

@Test func duplicatedManuscriptAndDeletionRoundTripWithoutAffectingOriginal() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ScriptLibraryStore(url: directory.appendingPathComponent("library.json"))
    let original = Manuscript(content: SavedReaderState(title: "Original", text: "Shared starting words.", fontSize: 28, followsPosition: false))
    let copy = Manuscript(content: original.content)
    var library = ScriptLibrary(manuscripts: [original, copy], selectedID: copy.id)
    library.manuscripts[1].content.title = "Copy"
    library.manuscripts[1].content.text = "Independent copy words."
    try store.save(library)

    var restored = try #require(try store.load())
    #expect(restored == library)
    #expect(restored.manuscripts[0].content.text == "Shared starting words.")
    #expect(restored.manuscripts[1].content.text == "Independent copy words.")
    #expect(restored.manuscripts[0].id != restored.manuscripts[1].id)
    restored.manuscripts.removeFirst()
    try store.save(restored)

    let afterDeletion = try #require(try store.load())
    #expect(afterDeletion == restored)
    #expect(afterDeletion.manuscripts.count == 1)
    #expect(afterDeletion.selected?.id == copy.id)
}

@Test func missingLibraryAndLegacyReturnNilWhileEmptyLibraryPersists() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("library.json")
    #expect(try ScriptLibraryStore(url: url).load() == nil)
    let store = ScriptLibraryStore(url: url, legacyURL: directory.appendingPathComponent("missing.json"))
    #expect(try store.load() == nil)
    #expect(!FileManager.default.fileExists(atPath: directory.path))

    let empty = ScriptLibrary(manuscripts: [], selectedID: nil)
    try store.save(empty)

    #expect(try store.load() == empty)
    #expect(try store.load()?.selected == nil)
}

@Test func invalidLibrarySavePreservesLastGoodBytes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ScriptLibraryStore(url: directory.appendingPathComponent("library.json"))
    let manuscript = Manuscript(content: SavedReaderState(title: "Good", text: "Keep these words."))
    let good = ScriptLibrary(manuscripts: [manuscript], selectedID: manuscript.id)
    try store.save(good)
    let originalBytes = try Data(contentsOf: store.url)
    var invalidLibraries = [
        ScriptLibrary(manuscripts: [manuscript, manuscript], selectedID: manuscript.id),
        ScriptLibrary(manuscripts: [manuscript], selectedID: UUID()),
        ScriptLibrary(manuscripts: [], selectedID: manuscript.id)
    ]
    let invalidContents = [
        SavedReaderState(title: "Bad", text: "Text", fontSize: .nan),
        SavedReaderState(title: "Bad", text: "Text", fontSize: .infinity),
        SavedReaderState(title: "Bad", text: "Text", fontSize: 17.99),
        SavedReaderState(title: "Bad", text: "Text", fontSize: 40.01),
        SavedReaderState(title: String(repeating: "T", count: 81), text: "Text"),
        SavedReaderState(title: "Long", text: String(repeating: "a", count: 100_001)),
        SavedReaderState(title: "UTF-16", text: String(repeating: "\u{1F600}", count: 50_001))
    ]
    for content in invalidContents {
        let invalid = Manuscript(content: content)
        invalidLibraries.append(ScriptLibrary(manuscripts: [manuscript, invalid], selectedID: manuscript.id))
    }

    for invalid in invalidLibraries {
        #expect(throws: (any Error).self) { try store.save(invalid) }
        #expect(try Data(contentsOf: store.url) == originalBytes)
        #expect(try store.load() == good)
    }
}

@Test func corruptPrimaryLibraryThrowsWithoutFallingBackToLegacy() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacyURL = directory.appendingPathComponent("script.json")
    try ScriptStore(url: legacyURL).save(SavedReaderState(title: "Legacy", text: "Do not replace the primary."))
    let legacyBytes = try Data(contentsOf: legacyURL)
    let url = directory.appendingPathComponent("library.json")
    let corruptBytes = Data("not a library".utf8)
    try corruptBytes.write(to: url)
    let store = ScriptLibraryStore(url: url, legacyURL: legacyURL)

    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: url) == corruptBytes)
    #expect(try Data(contentsOf: legacyURL) == legacyBytes)
}

@Test func invalidStoredLibraryThrowsAndPreservesBytes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("library.json")
    let manuscript = Manuscript(content: SavedReaderState(title: "Duplicate", text: "Same ID twice."))
    let invalidLibraries = [
        ScriptLibrary(manuscripts: [manuscript, manuscript], selectedID: manuscript.id),
        ScriptLibrary(manuscripts: [manuscript], selectedID: UUID()),
        ScriptLibrary(manuscripts: [Manuscript(content: SavedReaderState(title: "Invalid", text: "Text", fontSize: 50))], selectedID: nil)
    ]

    for invalid in invalidLibraries {
        let originalBytes = try JSONEncoder().encode(invalid)
        try originalBytes.write(to: url)
        #expect(throws: (any Error).self) { try ScriptLibraryStore(url: url).load() }
        #expect(try Data(contentsOf: url) == originalBytes)
    }
}

@Test func corruptOrInvalidLegacyThrowsWithoutCreatingLibrary() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let legacyURL = directory.appendingPathComponent("script.json")
    let url = directory.appendingPathComponent("library.json")
    let store = ScriptLibraryStore(url: url, legacyURL: legacyURL)
    let invalidLegacyData = [
        Data("not valid legacy JSON".utf8),
        Data(#"{"title":"Invalid","text":"Keep me.","fontSize":50}"#.utf8)
    ]

    for originalBytes in invalidLegacyData {
        try originalBytes.write(to: legacyURL)
        #expect(throws: (any Error).self) { try store.load() }
        #expect(try Data(contentsOf: legacyURL) == originalBytes)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
