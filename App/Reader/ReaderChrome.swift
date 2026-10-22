import SwiftUI

enum ReaderChrome {
    static let buttonFill = Color(red: 0.055, green: 0.42, blue: 0.333)
    static let motion = Animation.spring(response: 0.3, dampingFraction: 1)

    static func time(_ elapsed: Double) -> String {
        let seconds = Int(max(0, elapsed.isFinite ? elapsed : 0))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct ReaderGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                .overlay { Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
        } else {
            content.glassEffect(.regular, in: .capsule)
        }
    }
}

struct ReaderControlStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.94
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reducedMotion ? pressedScale : 1)
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
            .animation(reducedMotion ? nil : .smooth(duration: 0.16), value: configuration.isPressed)
    }
}
