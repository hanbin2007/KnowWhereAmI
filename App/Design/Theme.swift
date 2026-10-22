import SwiftUI
import UIKit

/// The reading room: warm paper, quiet ink, one evergreen accent.
enum Theme {
    static let paper = Color(uiColor: .paper)
    static let sheet = Color(uiColor: .dynamic(light: 0xFFFDF8, dark: 0x181D1B))
    static let raised = Color(uiColor: .dynamic(light: 0xEFEBE3, dark: 0x222826))
    static let ink = Color(uiColor: .ink)
    static let accent = Color.accentColor
    static let amber = Color(uiColor: .dynamic(light: 0xB7791A, dark: 0xF0B653))
    static let missed = Color(uiColor: .dynamic(light: 0xBE4A2C, dark: 0xF07D5E))
    static let onAir = Color(uiColor: .dynamic(light: 0xD23B2F, dark: 0xFF6158))
    static let track = Color.primary.opacity(0.08)
    static let hairline = Color.primary.opacity(0.09)

    /// Evergreen fill for the microphone, lifted slightly at the top edge.
    static var microphone: LinearGradient {
        LinearGradient(colors: [Color(red: 0.13, green: 0.52, blue: 0.42), Color(red: 0.035, green: 0.36, blue: 0.28)],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension UIColor {
    static var paper: UIColor { .dynamic(light: 0xF6F2EA, dark: 0x0E1110) }
    static var ink: UIColor { .dynamic(light: 0x1C211F, dark: 0xECE8E0) }
    /// Text already spoken: receded but still legible when rereading.
    static var spokenInk: UIColor { .dynamic(light: 0x8F958F, dark: 0x6C7470) }

    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

enum Motion {
    /// Layout changes such as the console morphing between modes.
    static let morph = Animation.spring(duration: 0.5, bounce: 0.14)
    /// Small state changes: selection, toggles, numbers.
    static let snappy = Animation.snappy(duration: 0.28)
    static let gentle = Animation.smooth(duration: 0.4)
    /// Data that draws itself once, such as report rings and maps.
    static let reveal = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 1.1)
}

/// Applies an animation unless the person prefers reduced motion.
struct CalmAnimation<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    func body(content: Content) -> some View {
        content.animation(reducedMotion ? nil : animation, value: value)
    }
}

extension View {
    func calmAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(CalmAnimation(animation: animation, value: value))
    }
}

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

/// A rounded surface that reads as paper laid on the desk.
struct SheetSurface: ViewModifier {
    var radius: CGFloat = 22
    var highlighted = false
    func body(content: Content) -> some View {
        content
            .background(Theme.sheet, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(highlighted ? Theme.accent.opacity(0.55) : Theme.hairline,
                                  lineWidth: highlighted ? 1.25 : 0.75)
            }
            .shadow(color: .black.opacity(0.045), radius: 14, y: 6)
    }
}

extension View {
    func sheetSurface(radius: CGFloat = 22, highlighted: Bool = false) -> some View {
        modifier(SheetSurface(radius: radius, highlighted: highlighted))
    }
}

/// Spoken-pace bands. Descriptive only; there is no "correct" rate.
enum PaceBand {
    case unhurried, conversational, brisk
    static let comfortable = 115.0...165.0

    init(wordsPerMinute: Double) {
        if wordsPerMinute < Self.comfortable.lowerBound { self = .unhurried }
        else if wordsPerMinute <= Self.comfortable.upperBound { self = .conversational }
        else { self = .brisk }
    }

    var title: String {
        switch self {
        case .unhurried: "Unhurried"
        case .conversational: "Conversational"
        case .brisk: "Brisk"
        }
    }
}

enum ReadingLength {
    /// Minutes to read aloud at a conversational 140 words per minute.
    static func minutes(words: Int) -> Int { max(1, Int((Double(words) / 140).rounded())) }

    static func summary(words: Int) -> String {
        words == 0 ? "Empty" : "\(words) \(words == 1 ? "word" : "words") \u{00B7} \(minutes(words: words)) min aloud"
    }
}
