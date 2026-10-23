import SwiftUI

/// A mask for the full-bleed manuscript: text fades out beneath the navigation
/// bar and just above the floating console, so glass never sits over legible
/// words. This mirrors the system soft scroll edge effect, which SwiftUI bars
/// do not apply to the UIKit reader.
struct ManuscriptEdgeFade: View {
    let insets: EdgeInsets
    let console: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: insets.top + 16)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 64)
            Color.clear
                .frame(height: max(0, console + insets.bottom - 12))
        }
    }
}
