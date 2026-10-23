import SwiftUI
import UIKit

/// The reading room: warm paper, quiet ink, one evergreen accent.
enum Theme {
    static let paper = Color(uiColor: .paper)
    static let sheet = Color(uiColor: .dynamic(light: 0xFFFDF8, dark: 0x181D1B))
    static let raised = Color(uiColor: .dynamic(light: 0xEFEBE3, dark: 0x222826))
    static let ink = Color(uiColor: .ink)
    /// The asset is referenced by name so the tint never falls back to system blue.
    static let accent = Color("AccentColor")
    /// Deep evergreen for tinted glass; white symbols stay legible in both appearances.
    static let accentDeep = Color(uiColor: .dynamic(light: 0x0E6B55, dark: 0x16735B))
    static let amber = Color(uiColor: .dynamic(light: 0xB7791A, dark: 0xF0B653))
    static let missed = Color(uiColor: .dynamic(light: 0xBE4A2C, dark: 0xF07D5E))
    static let onAir = Color(uiColor: .dynamic(light: 0xD23B2F, dark: 0xFF6158))
    static let track = Color.primary.opacity(0.08)
    static let hairline = Color.primary.opacity(0.09)
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
