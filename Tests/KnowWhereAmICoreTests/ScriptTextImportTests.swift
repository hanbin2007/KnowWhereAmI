import Foundation
import Testing
@testable import KnowWhereAmICore

@Test func importsUTF8AndUTF16TextWithoutByteOrderMarks() throws {
    #expect(try ScriptTextImport.decode(Data([0xEF, 0xBB, 0xBF] + Array("Hello, everyone.".utf8))) == "Hello, everyone.")
    let utf16 = try #require("A new paragraph.".data(using: .utf16))
    #expect(try ScriptTextImport.decode(utf16) == "A new paragraph.")
}

@Test func rejectsBinaryAndOversizedImports() {
    #expect(throws: (any Error).self) { try ScriptTextImport.decode(Data([0, 1, 2, 3])) }
    #expect(throws: (any Error).self) { try ScriptTextImport.decode(Data(repeating: 65, count: 100_001)) }
}
