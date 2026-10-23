import SwiftUI

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
