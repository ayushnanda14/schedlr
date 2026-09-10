import SwiftUI
import UIKit

enum AnchorColor {
    // Vermillion isolate: near-neutral surfaces, one saturated accent.
    static let background = adaptive(light: 0xF6F4F1, dark: 0x0D0D0E)
    static let backgroundWash = background
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x161617)
    static let surfaceMuted = adaptive(light: 0xEFECE7, dark: 0x1C1C1D)
    static let textPrimary = adaptive(light: 0x292724, dark: 0xE5E4E1)
    static let textSecondary = adaptive(light: 0x96938C, dark: 0x7A7873)
    static let border = adaptive(light: 0xE6E3DE, dark: 0x262627)
    static let brand = adaptive(light: 0xB8451F, dark: 0xE0522E)
    static let brandSoft = adaptive(light: 0xFBE6DE, dark: 0x211613)
    static let brandDeep = brand
    static let onBrand = adaptive(light: 0xFFF8F5, dark: 0xFFF4F0)
    static let accentAttention = adaptive(light: 0xB86A1C, dark: 0xE0A15A)
    static let accentAttentionSoft = adaptive(light: 0xF4E4CC, dark: 0x3A2F20)
    static let accentInfo = textSecondary
    static let danger = adaptive(light: 0xA43B32, dark: 0xE08B84)
    static let focusRing = brand

    static var uiBackground: UIColor { ui(light: 0xF6F4F1, dark: 0x0D0D0E) }
    static var uiSurface: UIColor { ui(light: 0xFFFFFF, dark: 0x161617) }
    static var uiSurfaceMuted: UIColor { ui(light: 0xEFECE7, dark: 0x1C1C1D) }
    static var uiBrand: UIColor { ui(light: 0xB8451F, dark: 0xE0522E) }
    static var uiBrandSoft: UIColor { ui(light: 0xFBE6DE, dark: 0x211613) }
    static var uiOnBrand: UIColor { ui(light: 0xFFF8F5, dark: 0xFFF4F0) }
    static var uiTextPrimary: UIColor { ui(light: 0x292724, dark: 0xE5E4E1) }
    static var uiTextSecondary: UIColor { ui(light: 0x96938C, dark: 0x7A7873) }
    static var uiBorder: UIColor { ui(light: 0xE6E3DE, dark: 0x262627) }

    static let isolatePage = background
    static let isolateSurface = surface
    static let isolateBorder = border
    static let isolateBorderAccent = brand
    static let isolateTextPrimary = textPrimary
    static let isolateTextSecondary = textSecondary
    static let isolateAccent = brand
    static let isolateAccentTint = brandSoft

    static var uiIsolatePage: UIColor { uiBackground }
    static var uiIsolateSurface: UIColor { uiSurface }
    static var uiIsolateBorder: UIColor { uiBorder }
    static var uiIsolateAccent: UIColor { uiBrand }
    static var uiIsolateAccentTint: UIColor { uiBrandSoft }

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
