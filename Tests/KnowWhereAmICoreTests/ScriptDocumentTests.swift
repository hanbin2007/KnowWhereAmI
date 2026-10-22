import Foundation
import Testing
@testable import KnowWhereAmICore

@Test func tokenRangesPreserveOriginalPunctuationAndUnicodeOffsets() {
    let text = "\u{1F399} Hello, world! Don't stop."
    let document = ScriptDocument(text: text)
    #expect(document.words.map(\.text) == ["Hello", "world", "Don't", "stop"])
    #expect(document.words.first?.range == NSRange(location: 3, length: 5))
    for word in document.words {
        #expect((text as NSString).substring(with: word.range) == word.text)
    }
}

@Test func wordHitTestingDoesNotSelectWhitespaceOrOutOfBounds() {
    let document = ScriptDocument(text: "One two.")
    #expect(document.wordIndex(atUTF16Offset: 1) == 0)
    #expect(document.wordIndex(atUTF16Offset: 4) == 1)
    #expect(document.wordIndex(atUTF16Offset: 3) == nil)
    #expect(document.wordIndex(atUTF16Offset: 8) == nil)
    #expect(document.wordIndex(atUTF16Offset: -1) == nil)
}
