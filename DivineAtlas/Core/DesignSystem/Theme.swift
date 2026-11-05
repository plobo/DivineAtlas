import SwiftUI
import UIKit

/// Design tokens for the editorial encyclopedia look: deep charcoal surfaces,
/// restrained antique-gold accents, serif display type over system sans-serif.
enum Theme {
    enum Palette {
        static let background = Color(red: 0.067, green: 0.075, blue: 0.098)
        static let surface = Color(red: 0.106, green: 0.118, blue: 0.149)
        static let surfaceRaised = Color(red: 0.153, green: 0.165, blue: 0.204)
        static let border = Color.white.opacity(0.10)
        /// Antique gold; ~8:1 contrast against `background`.
        static let gold = Color(red: 0.831, green: 0.706, blue: 0.443)
        static let textPrimary = Color.white.opacity(0.94)
        /// ~9:1 contrast against `background`.
        static let textSecondary = Color.white.opacity(0.70)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
    }

    /// UIKit appearance for navigation bars, so titles use the serif display face.
    @MainActor
    static func configureAppearance() {
        func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight, maximumPointSize: CGFloat) -> UIFont {
            // Start from the default-size metrics and let UIFontMetrics scale
            // with Dynamic Type, capped so titles stay readable rather than
            // truncating ("Gods…") at the largest accessibility sizes.
            let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
            let weighted = base.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
            let descriptor = weighted.withDesign(.serif) ?? weighted
            return UIFontMetrics(forTextStyle: style).scaledFont(
                for: UIFont(descriptor: descriptor, size: base.pointSize),
                maximumPointSize: maximumPointSize
            )
        }
        let gold = UIColor(Palette.gold)
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: serif(.largeTitle, weight: .semibold, maximumPointSize: 40), .foregroundColor: UIColor(Palette.textPrimary)]
        appearance.titleTextAttributes = [.font: serif(.headline, weight: .semibold, maximumPointSize: 28), .foregroundColor: UIColor(Palette.textPrimary)]
        appearance.tintColor = gold
    }
}

extension Font {
    static let displayLarge = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let displayTitle = Font.system(.title2, design: .serif).weight(.semibold)
    static let entityTitle = Font.system(.title3, design: .serif).weight(.semibold)
    static let sectionTitle = Font.system(.headline, design: .serif)
}

extension View {
    /// Full-bleed screen background used by every top-level screen.
    func themedScreenBackground() -> some View {
        background(Theme.Palette.background.ignoresSafeArea())
    }

    /// Card surface with a subtle border.
    func cardSurface() -> some View {
        self
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
    }
}
