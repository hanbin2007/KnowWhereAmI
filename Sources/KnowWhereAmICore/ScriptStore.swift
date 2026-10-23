import Foundation

public struct SavedReaderState: Codable, Equatable, Sendable {
    public var title: String
    public var text: String
    public var fontSize: Double
    public var followsPosition: Bool
    public var liveTimeLimitSeconds: Int

    public init(title: String, text: String, fontSize: Double = 26, followsPosition: Bool = true,
                liveTimeLimitSeconds: Int = 180) {
        self.title = title
        self.text = text
        self.fontSize = fontSize
        self.followsPosition = followsPosition
        self.liveTimeLimitSeconds = liveTimeLimitSeconds
    }

    private enum CodingKeys: String, CodingKey { case title, text, fontSize, followsPosition, liveTimeLimitSeconds }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        text = try values.decode(String.self, forKey: .text)
        fontSize = try values.decode(Double.self, forKey: .fontSize)
        followsPosition = try values.decodeIfPresent(Bool.self, forKey: .followsPosition) ?? true
        liveTimeLimitSeconds = try values.decodeIfPresent(Int.self, forKey: .liveTimeLimitSeconds) ?? 180
    }
}

public struct ScriptStore: Sendable {
    public static let maximumTextLength = 100_000
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> SavedReaderState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(SavedReaderState.self, from: data)
        try Self.validate(state)
        return state
    }

    public func save(_ state: SavedReaderState) throws {
        try Self.validate(state)
        let data = try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    static func validate(_ state: SavedReaderState) throws {
        guard state.fontSize.isFinite, (18...40).contains(state.fontSize) else { throw ScriptStorageError.invalidTextSize }
        guard LiveTimingSession.allowedLimits.contains(state.liveTimeLimitSeconds) else { throw ScriptStorageError.invalidLiveTimeLimit }
        guard state.title.count <= 80 else { throw ScriptStorageError.titleTooLong }
        guard state.text.utf16.count <= Self.maximumTextLength else { throw ScriptStorageError.scriptTooLong }
    }
}

public enum ScriptStorageError: LocalizedError {
    case invalidTextSize, titleTooLong, scriptTooLong, invalidLiveTimeLimit

    public var errorDescription: String? {
        switch self {
        case .invalidTextSize: "Text size must be between 18 and 40 points."
        case .titleTooLong: "The title must be 80 characters or fewer."
        case .scriptTooLong: "The script must be 100,000 characters or fewer."
        case .invalidLiveTimeLimit: "The live time limit must be between 30 seconds and 60 minutes."
        }
    }
}
