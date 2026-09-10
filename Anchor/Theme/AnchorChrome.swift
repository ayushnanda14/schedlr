import SwiftUI
import UIKit

@Observable
final class AnchorCapturePresentation {
    var showCapture = false
}

private struct AnchorUsesTabAccessoryKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var anchorUsesTabAccessory: Bool {
        get { self[AnchorUsesTabAccessoryKey.self] }
        set { self[AnchorUsesTabAccessoryKey.self] = newValue }
    }
}

enum AnchorSurfaceKind {
    case hero
    case raised
    case inset
    case flush
}

struct AnchorScreenBackground: View {
    var body: some View {
        AnchorColor.background
            .ignoresSafeArea()
    }
}

struct AnchorSurfaceModifier: ViewModifier {
    var kind: AnchorSurfaceKind

    func body(content: Content) -> some View {
        switch kind {
        case .hero:
            content
                .background(AnchorColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AnchorRadius.hero, style: .continuous)
                        .strokeBorder(AnchorColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.hero, style: .continuous))
        case .raised:
            content
                .background(AnchorColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous)
                        .strokeBorder(AnchorColor.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous))
        case .inset:
            content
                .background(AnchorColor.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.control, style: .continuous))
        case .flush:
            content
        }
    }
}

struct AnchorHairline: View {
    var body: some View {
        Rectangle()
            .fill(AnchorColor.border)
            .frame(height: 1)
    }
}

struct StatusPill: View {
    var text: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral
        case brand
        case attention
    }

    var body: some View {
        Text(text)
            .font(AnchorFont.micro)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(border, lineWidth: 1)
            )
            .accessibilityAddTraits(.isStaticText)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return AnchorColor.textSecondary
        case .brand: return AnchorColor.brand
        case .attention: return AnchorColor.accentAttention
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: return AnchorColor.surfaceMuted
        case .brand: return AnchorColor.brandSoft
        case .attention: return AnchorColor.accentAttentionSoft
        }
    }

    private var border: Color {
        switch tone {
        case .neutral: return AnchorColor.border
        case .brand: return AnchorColor.brand.opacity(0.35)
        case .attention: return AnchorColor.accentAttention.opacity(0.28)
        }
    }
}

struct AnchorSectionLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(AnchorFont.section)
            .foregroundStyle(AnchorColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct AnchorCompactActionButton: View {
    var title: String
    var isProminent: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AnchorFont.captionEmphasized)
                .foregroundStyle(isProminent ? AnchorColor.brand : AnchorColor.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isProminent ? AnchorColor.brandSoft : AnchorColor.surfaceMuted)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isProminent ? AnchorColor.brand.opacity(0.35) : AnchorColor.border, lineWidth: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

extension View {
    func anchorSurface(_ kind: AnchorSurfaceKind = .raised) -> some View {
        modifier(AnchorSurfaceModifier(kind: kind))
    }

    func anchorScreen() -> some View {
        tint(AnchorColor.brand)
            .background(AnchorScreenBackground())
    }

    func anchorField() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AnchorColor.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.chip, style: .continuous))
    }

    func anchorChoiceChip(selected: Bool) -> some View {
        background(selected ? AnchorColor.brandSoft : AnchorColor.surfaceMuted)
            .foregroundStyle(selected ? AnchorColor.brand : AnchorColor.textPrimary)
            .clipShape(Capsule())
    }

    func anchorTabRoot() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AnchorColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AnchorColor.background, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .anchorHardScrollEdge(.bottom)
    }

    /// Keeps the iOS 26 tab bar from sampling scrolling titles through glass.
    @ViewBuilder
    func anchorTabViewChrome() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.never)
        } else {
            self
        }
    }

    @ViewBuilder
    func anchorHardScrollEdge(_ edges: Edge.Set) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.hard, for: edges)
        } else {
            self
        }
    }
}

enum AnchorTheme {
    static func install() {
        let brand = AnchorColor.uiBrand
        let background = AnchorColor.uiBackground
        let surface = AnchorColor.uiSurface
        let muted = AnchorColor.uiSurfaceMuted
        let text = AnchorColor.uiTextPrimary
        let secondary = AnchorColor.uiTextSecondary

        UIView.appearance().tintColor = brand
        UIWindow.appearance().backgroundColor = background

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = background
        nav.shadowColor = AnchorColor.uiBorder.withAlphaComponent(0.55)
        nav.titleTextAttributes = [
            .font: AnchorFont.ui("Lato-Bold", size: 18, textStyle: .headline),
            .foregroundColor: text
        ]
        nav.largeTitleTextAttributes = [
            .font: AnchorFont.ui("Lato-Bold", size: 28, textStyle: .largeTitle),
            .foregroundColor: text
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactScrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = brand

        if #available(iOS 26.0, *) {
                // Don't fight the Liquid Glass tab bar with legacy UITabBarAppearance.
                // Let SwiftUI's .tint() + .toolbarBackground(_:for:.tabBar) (already
                // applied via anchorTabRoot()) drive tab bar color instead.
//                UITabBar.appearance().tintColor = brand
//                UITabBar.appearance().unselectedItemTintColor = secondary
            } else {
                let tab = UITabBarAppearance()
                tab.configureWithOpaqueBackground()
                tab.backgroundEffect = nil
                tab.backgroundColor = background
                tab.shadowColor = AnchorColor.uiBorder
                applyTabItemColors(tab.stackedLayoutAppearance, brand: brand, secondary: secondary)
                applyTabItemColors(tab.inlineLayoutAppearance, brand: brand, secondary: secondary)
                applyTabItemColors(tab.compactInlineLayoutAppearance, brand: brand, secondary: secondary)
                UITabBar.appearance().standardAppearance = tab
                UITabBar.appearance().scrollEdgeAppearance = tab
                UITabBar.appearance().isTranslucent = false
                UITabBar.appearance().barTintColor = background
                UITabBar.appearance().backgroundColor = background
                UITabBar.appearance().tintColor = brand
                UITabBar.appearance().unselectedItemTintColor = secondary
            }

        UISegmentedControl.appearance().selectedSegmentTintColor = surface
        UISegmentedControl.appearance().backgroundColor = muted
        UISegmentedControl.appearance().setTitleTextAttributes([
            .font: AnchorFont.ui("Lato-Bold", size: 13, textStyle: .footnote),
            .foregroundColor: brand
        ], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([
            .font: AnchorFont.ui("Lato-Regular", size: 13, textStyle: .footnote),
            .foregroundColor: secondary
        ], for: .normal)

        UITableView.appearance().backgroundColor = background
        UICollectionView.appearance().backgroundColor = background
    }

    private static func applyTabItemColors(
        _ item: UITabBarItemAppearance,
        brand: UIColor,
        secondary: UIColor
    ) {
        item.normal.iconColor = secondary
        item.normal.titleTextAttributes = [.foregroundColor: secondary]
        item.selected.iconColor = brand
        item.selected.titleTextAttributes = [.foregroundColor: brand]
        item.normal.titlePositionAdjustment = .zero
        item.selected.titlePositionAdjustment = .zero
    }
}
