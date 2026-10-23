import SwiftUI

enum ReaderChrome {
    static func time(_ elapsed: Double) -> String {
        let seconds = Int(max(0, elapsed.isFinite ? elapsed : 0))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// Press feedback for content-layer buttons such as cards. Glass controls use
/// interactive glass instead.
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
