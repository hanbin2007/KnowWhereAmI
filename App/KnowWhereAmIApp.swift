import SwiftUI
import UIKit

@main
struct KnowWhereAmIApp: App {
    init() {
        // Editorial New York titles; the bars themselves stay system Liquid Glass.
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: Self.serif(.largeTitle, weight: .bold)]
        bar.titleTextAttributes = [.font: Self.serif(.headline, weight: .semibold)]
    }

    var body: some Scene {
        WindowGroup { ReaderView() }
    }

    private static func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let font = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }
}
