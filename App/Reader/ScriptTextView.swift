import KnowWhereAmICore
import SwiftUI
import UIKit

struct ScriptTextView: UIViewRepresentable {
    let document: ScriptDocument
    let cursor: Int?
    let isTentative: Bool
    let fontSize: Double
    let followsPosition: Bool
    let recenterID: Int
    let onSelect: (Int) -> Void
    let onManualScroll: () -> Void
    var onManualScrollEnd: (() -> Void)? = nil
    var allowsInteraction = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> ReaderTextSurface { ReaderTextSurface() }

    func updateUIView(_ view: ReaderTextSurface, context: Context) {
        view.onSelect = onSelect
        view.onManualScroll = onManualScroll
        view.onManualScrollEnd = onManualScrollEnd
        view.configure(document: document, cursor: cursor, tentative: isTentative,
                       pointSize: fontSize, dark: colorScheme == .dark,
                       typeSize: dynamicTypeSize, follows: followsPosition,
                       recenter: recenterID, reducedMotion: reduceMotion, allowsInteraction: allowsInteraction)
    }
}
