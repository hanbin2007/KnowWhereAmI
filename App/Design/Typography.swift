import SwiftUI

extension Font {
    /// Editorial serif (New York) for titles and manuscript text.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// Rounded figures for measurements.
    static func figure(_ style: Font.TextStyle, weight: Font.Weight = .medium) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
