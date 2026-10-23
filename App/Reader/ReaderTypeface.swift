import SwiftUI

/// The manuscript typeface, chosen once for every script.
enum ReaderTypeface: String, CaseIterable, Identifiable {
    case serif, sans
    static let storageKey = "readerTypeface"
    var id: String { rawValue }
    var title: String { self == .serif ? "New York" : "SF Pro" }
    var design: Font.Design { self == .serif ? .serif : .default }
}
