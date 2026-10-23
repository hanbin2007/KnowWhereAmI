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

/// Small tracked capitals used to label sections and context.
struct Eyebrow: View {
    let text: String
    var color: Color = .secondary
    init(_ text: String, color: Color = .secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
