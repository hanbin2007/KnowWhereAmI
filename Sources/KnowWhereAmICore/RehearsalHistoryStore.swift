import Foundation

public struct RehearsalRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let manuscriptID: UUID
    public let title: String
    public let scriptText: String
    public let startedAt: Date
    public let endedAt: Date
    public let statistics: RehearsalStatistics

    public init(id: UUID = UUID(), manuscriptID: UUID, title: String, scriptText: String,
                startedAt: Date, endedAt: Date, statistics: RehearsalStatistics) {
        self.id = id
        self.manuscriptID = manuscriptID
        self.title = title
        self.scriptText = scriptText
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.statistics = statistics
    }
}

public struct RehearsalHistoryStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> [RehearsalRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([RehearsalRecord].self, from: Data(contentsOf: url))
    }

    public func save(_ records: [RehearsalRecord]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
