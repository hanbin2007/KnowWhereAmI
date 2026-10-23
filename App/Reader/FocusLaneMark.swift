import SwiftUI

/// The marker in the left margin where the spoken line settles.
struct FocusLaneMark: View {
    let locked: Bool
    let tentative: Bool
    let following: Bool
    /// Height of the text it sits beside, so the mark matches the line.
    var textHeight: CGFloat = 22

    var body: some View {
        ZStack {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Capsule()
                    .fill(tentative ? Theme.amber : Theme.accent)
                    .frame(width: 3, height: following ? textHeight : textHeight * 0.45)
                    .opacity(following ? 0.75 : 0.35)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 14, height: textHeight)
        .calmAnimation(Motion.snappy, value: locked)
        .calmAnimation(Motion.snappy, value: following)
        .calmAnimation(Motion.snappy, value: tentative)
    }
}
