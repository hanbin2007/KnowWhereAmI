import Foundation

public enum ReadingFocus {
    public static let fraction = 0.34
    public static func insets(viewportHeight: Double, lineHeight: Double, textInset: Double) -> (top: Double, bottom: Double) {
        guard viewportHeight.isFinite, lineHeight.isFinite, textInset.isFinite else { return (0, 0) }
        return (max(0, viewportHeight * fraction - lineHeight / 2 - textInset),
                max(0, viewportHeight * (1 - fraction)))
    }
    public static func offset(lineMidY: Double, viewportHeight: Double, contentHeight: Double, topInset: Double, bottomInset: Double) -> Double {
        guard [lineMidY, viewportHeight, contentHeight, topInset, bottomInset].allSatisfy(\.isFinite) else { return 0 }
        let minimum = -max(0, topInset)
        let maximum = max(minimum, contentHeight - viewportHeight + bottomInset)
        return min(maximum, max(minimum, lineMidY - viewportHeight * fraction))
    }
}

public struct FocusSpring: Sendable {
    public private(set) var position: Double
    public private(set) var velocity: Double = 0
    public private(set) var target: Double
    public var isSettled: Bool { abs(position - target) < 0.15 && abs(velocity) < 0.8 }
    public init(position: Double = 0) { self.position = position; self.target = position }
    public mutating func retarget(_ value: Double) { if value.isFinite { target = value } }
    public mutating func jump(to value: Double) {
        guard value.isFinite else { return }
        position = value; target = value; velocity = 0
    }
    @discardableResult public mutating func step(elapsed: Double) -> Double {
        guard elapsed.isFinite, elapsed > 0 else { return position }
        if elapsed > 0.5 { jump(to: target); return position }
        let omega = 20.0
        let displacement = position - target
        let coefficient = velocity + omega * displacement
        let decay = exp(-omega * elapsed)
        position = target + (displacement + coefficient * elapsed) * decay
        velocity = (velocity - omega * coefficient * elapsed) * decay
        return position
    }
}
