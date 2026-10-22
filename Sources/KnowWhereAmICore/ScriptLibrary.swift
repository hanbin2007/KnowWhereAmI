import Foundation

public struct Manuscript: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var content: SavedReaderState
    public var createdAt: Date
    public var modifiedAt: Date

    public init(id: UUID = UUID(), content: SavedReaderState, createdAt: Date = Date(), modifiedAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct ScriptLibrary: Codable, Equatable, Sendable {
    public var manuscripts: [Manuscript]
    public var selectedID: UUID?

    public var selected: Manuscript? {
        guard let selectedID else { return nil }
        return manuscripts.first { $0.id == selectedID }
    }

    public init(manuscripts: [Manuscript], selectedID: UUID?) {
        self.manuscripts = manuscripts
        self.selectedID = selectedID
    }
}

public struct ScriptLibraryStore: Sendable {
    public let url: URL
    private let legacyURL: URL?

    public init(url: URL, legacyURL: URL? = nil) {
        self.url = url
        self.legacyURL = legacyURL
    }

    public func load() throws -> ScriptLibrary? {
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            let library = try JSONDecoder().decode(ScriptLibrary.self, from: data)
            try validate(library)
            return library
        }

        guard let legacyURL, let content = try ScriptStore(url: legacyURL).load() else { return nil }
        let timestamp = Date()
        let manuscript = Manuscript(content: content, createdAt: timestamp, modifiedAt: timestamp)
        let library = ScriptLibrary(manuscripts: [manuscript], selectedID: manuscript.id)
        try save(library)
        return library
    }

    public func save(_ library: ScriptLibrary) throws {
        try validate(library)
        let data = try JSONEncoder().encode(library)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func validate(_ library: ScriptLibrary) throws {
        let ids = Set(library.manuscripts.map(\.id))
        guard ids.count == library.manuscripts.count else { throw ScriptLibraryStorageError.duplicateManuscriptIDs }
        if let selectedID = library.selectedID, !ids.contains(selectedID) {
            throw ScriptLibraryStorageError.selectionNotFound
        }
        for manuscript in library.manuscripts {
            try ScriptStore.validate(manuscript.content)
        }
    }
}

public enum ScriptLibraryStorageError: LocalizedError {
    case duplicateManuscriptIDs, selectionNotFound

    public var errorDescription: String? {
        switch self {
        case .duplicateManuscriptIDs: "Each manuscript must have a unique ID."
        case .selectionNotFound: "The selected manuscript is not in the library."
        }
    }
}
