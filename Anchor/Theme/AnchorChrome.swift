import SwiftUI
import UIKit

enum AnchorSurfaceKind {
    case hero
    case raised
    case inset
    case flush
}

struct AnchorScreenBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                AnchorColor.background,
                AnchorColor.backgroundWash,
                AnchorColor.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(AnchorColor.brandSoft.opacity(0.55))
                .frame(width: 240, height: 240)
                .blur(radius: 48)
                .offset(x: 70, y: -90)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(AnchorColor.brand.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: -80, y: 60)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct AnchorSurfaceModifier: ViewModifier {
    var kind: AnchorSurfaceKind

    func body(content: Content) -> some View {
        switch kind {
        case .hero:
            content
                .background(heroFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AnchorRadius.hero, style: .continuous)
                        .strokeBorder(AnchorColor.brand.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.hero, style: .continuous))
                .shadow(color: AnchorColor.brand.opacity(0.12), radius: 18, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        case .raised:
            content
                .background(AnchorColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous)
                        .strokeBorder(AnchorColor.border.opacity(0.9), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.surface, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                .shadow(color: AnchorColor.brand.opacity(0.05), radius: 10, x: 0, y: 5)
        case .inset:
            content
                .background(AnchorColor.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: AnchorRadius.control, style: .continuous))
        case .flush:
            content
        }
    }

    private var heroFill: LinearGradient {
        LinearGradient(
            colors: [
                AnchorColor.brandSoft,
                AnchorColor.surface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AnchorHairline: View {
    var body: some View {
        Rectangle()
            .fill(AnchorColor.border.opacity(0.7))
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
        case .brand: return AnchorColor.brandDeep
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
        case .brand: return AnchorColor.brand.opacity(0.2)
        case .attention: return AnchorColor.accentAttention.opacity(0.25)
        }
    }
}

struct AnchorSectionLabel: View {
    var title: String

    var body: some View {
        Text(title)
            .font(AnchorFont.section)
            .foregroundStyle(AnchorColor.textPrimary)
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
                .foregroundStyle(isProminent ? AnchorColor.onBrand : AnchorColor.brandDeep)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isProminent ? AnchorColor.brand : AnchorColor.brandSoft)
                .clipShape(Capsule())
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

    func anchorTabRoot() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AnchorColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        let text = AnchorColor.uiTextPrimary
        let secondary = AnchorColor.uiTextSecondary

        UIView.appearance().tintColor = brand

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = background
        nav.shadowColor = AnchorColor.uiBorder.withAlphaComponent(0.4)
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

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundEffect = nil
        tab.backgroundColor = surface
        tab.shadowColor = AnchorColor.uiBorder
        applyTabItemColors(tab.stackedLayoutAppearance, brand: brand, secondary: secondary)
        applyTabItemColors(tab.inlineLayoutAppearance, brand: brand, secondary: secondary)
        applyTabItemColors(tab.compactInlineLayoutAppearance, brand: brand, secondary: secondary)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = surface
        UITabBar.appearance().backgroundColor = surface
        UITabBar.appearance().tintColor = brand
        UITabBar.appearance().unselectedItemTintColor = secondary

        let onBrand = AnchorColor.ui(light: 0xF7FBF8, dark: 0x102016)
        let segmentTrack = AnchorColor.ui(light: 0xD5E0D7, dark: 0x242C26)
        UISegmentedControl.appearance().selectedSegmentTintColor = brand
        UISegmentedControl.appearance().backgroundColor = segmentTrack
        UISegmentedControl.appearance().setTitleTextAttributes([
            .font: AnchorFont.ui("Lato-Bold", size: 13, textStyle: .footnote),
            .foregroundColor: onBrand
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
