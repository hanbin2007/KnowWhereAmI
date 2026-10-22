import Foundation

public enum ScriptTextImport {
    public static func decode(_ data: Data) throws -> String {
        guard data.count <= 1_000_000 else { throw ScriptStorageError.scriptTooLong }
        let hasUTF16Mark = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
        let encoding: String.Encoding = hasUTF16Mark ? .utf16 : .utf8
        guard var text = String(data: data, encoding: encoding), !text.contains("\0") else {
            throw ImportError.notText
        }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        guard text.utf16.count <= ScriptStore.maximumTextLength else { throw ScriptStorageError.scriptTooLong }
        return text
    }

    private enum ImportError: LocalizedError {
        case notText
        var errorDescription: String? { "Choose a UTF-8 or UTF-16 plain text file (.txt or .md)." }
    }
}
