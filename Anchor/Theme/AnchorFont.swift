import SwiftUI
import UIKit

/// Product typeface is Lato, scaled with Dynamic Type. System UI fonts are the fallback
/// if a face is missing from the bundle.
enum AnchorFont {
    static let display = face("Lato-Bold", size: 32, relativeTo: .largeTitle)
    static let heading = face("Lato-Bold", size: 22, relativeTo: .title2)
    static let title = face("Lato-Medium", size: 17, relativeTo: .headline)
    static let section = face("Lato-Bold", size: 15, relativeTo: .subheadline)
    static let body = face("Lato-Regular", size: 17, relativeTo: .body)
    static let bodyEmphasized = face("Lato-Medium", size: 17, relativeTo: .body)
    static let callout = face("Lato-Regular", size: 16, relativeTo: .callout)
    static let subheadline = face("Lato-Regular", size: 15, relativeTo: .subheadline)
    static let subheadlineEmphasized = face("Lato-Medium", size: 15, relativeTo: .subheadline)
    static let footnote = face("Lato-Regular", size: 13, relativeTo: .footnote)
    static let caption = face("Lato-Regular", size: 12, relativeTo: .caption)
    static let captionEmphasized = face("Lato-Medium", size: 12, relativeTo: .caption)
    static let micro = face("Lato-Medium", size: 11, relativeTo: .caption2)

    static func ui(_ name: String, size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight(name))
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    private static func face(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }

    private static func fallbackWeight(_ name: String) -> UIFont.Weight {
        if name.contains("Bold") { return .bold }
        if name.contains("Medium") { return .medium }
        return .regular
    }
}
