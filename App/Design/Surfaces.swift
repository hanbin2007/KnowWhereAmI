import SwiftUI

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
