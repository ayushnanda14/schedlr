import SwiftUI
import UIKit

enum AnchorColor {
    static let background = adaptive(light: 0xF3F6F2, dark: 0x101411)
    static let backgroundWash = adaptive(light: 0xE4EEE6, dark: 0x161C18)
    static let surface = adaptive(light: 0xFBFCF9, dark: 0x1B221D)
    static let surfaceMuted = adaptive(light: 0xE8EFE9, dark: 0x242C26)
    static let textPrimary = adaptive(light: 0x1C211D, dark: 0xF2F5F1)
    static let textSecondary = adaptive(light: 0x5C665F, dark: 0xA7B0A8)
    static let border = adaptive(light: 0xD4DDD6, dark: 0x313832)
    static let brand = adaptive(light: 0x2F6A4A, dark: 0x7FBF96)
    static let brandSoft = adaptive(light: 0xC5DCCB, dark: 0x24352A)
    static let brandDeep = adaptive(light: 0x1F4A34, dark: 0x9FD4B0)
    static let onBrand = adaptive(light: 0xF7FBF8, dark: 0x102016)
    static let accentAttention = adaptive(light: 0xB86A1C, dark: 0xE0A15A)
    static let accentAttentionSoft = adaptive(light: 0xF4E4CC, dark: 0x3A2C18)
    static let accentInfo = adaptive(light: 0x2A6B68, dark: 0x7AB8B4)
    static let danger = adaptive(light: 0xA43B32, dark: 0xE08B84)
    static let focusRing = adaptive(light: 0x2F6A4A, dark: 0x7FBF96)

    static var uiBackground: UIColor { ui(light: 0xF3F6F2, dark: 0x101411) }
    static var uiSurface: UIColor { ui(light: 0xFBFCF9, dark: 0x1B221D) }
    static var uiBrand: UIColor { ui(light: 0x2F6A4A, dark: 0x7FBF96) }
    static var uiTextPrimary: UIColor { ui(light: 0x1C211D, dark: 0xF2F5F1) }
    static var uiTextSecondary: UIColor { ui(light: 0x5C665F, dark: 0xA7B0A8) }
    static var uiBorder: UIColor { ui(light: 0xD4DDD6, dark: 0x313832) }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: ui(light: light, dark: dark))
    }

    static func ui(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }
}

enum AnchorRadius {
    static let chip: CGFloat = 8
    static let control: CGFloat = 12
    static let surface: CGFloat = 16
    static let hero: CGFloat = 20
}

enum AnchorSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum AnchorMotion {
    static func fade(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    static func snappy(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
