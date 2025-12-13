import SwiftUI

enum AppGradient {
    // Theme-aware gradients
    static func background(for theme: ColorTheme) -> some View {
        LinearGradient(
            colors: theme.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    static func radialBackground(for theme: ColorTheme) -> some View {
        RadialGradient(
            colors: theme.radialColors,
            center: .top,
            startRadius: 100,
            endRadius: 600
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    static func meshBackground(for theme: ColorTheme) -> some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: theme.meshColors
            )
            .ignoresSafeArea()
        } else {
            background(for: theme)
        }
    }

    // Legacy static versions (fallback to ocean)
    static var background: some View {
        background(for: .ocean)
    }

    static var radialBackground: some View {
        radialBackground(for: .ocean)
    }

    static var meshBackground: some View {
        meshBackground(for: .ocean)
    }
}

extension ColorTheme {
    var gradientColors: [Color] {
        switch self {
        case .ocean:
            return [
                Color(red: 0.08, green: 0.12, blue: 0.22),
                Color(red: 0.04, green: 0.18, blue: 0.28),
                Color(red: 0.02, green: 0.10, blue: 0.18),
                Color(red: 0.02, green: 0.04, blue: 0.08)
            ]
        case .sunset:
            return [
                Color(red: 0.28, green: 0.12, blue: 0.16),
                Color(red: 0.32, green: 0.16, blue: 0.12),
                Color(red: 0.22, green: 0.08, blue: 0.14),
                Color(red: 0.08, green: 0.02, blue: 0.04)
            ]
        case .forest:
            return [
                Color(red: 0.06, green: 0.16, blue: 0.12),
                Color(red: 0.08, green: 0.22, blue: 0.14),
                Color(red: 0.04, green: 0.14, blue: 0.10),
                Color(red: 0.02, green: 0.06, blue: 0.04)
            ]
        case .lavender:
            return [
                Color(red: 0.18, green: 0.12, blue: 0.26),
                Color(red: 0.22, green: 0.14, blue: 0.32),
                Color(red: 0.14, green: 0.08, blue: 0.22),
                Color(red: 0.06, green: 0.04, blue: 0.10)
            ]
        case .midnight:
            return [
                Color(red: 0.08, green: 0.08, blue: 0.14),
                Color(red: 0.10, green: 0.10, blue: 0.18),
                Color(red: 0.06, green: 0.06, blue: 0.12),
                Color(red: 0.02, green: 0.02, blue: 0.06)
            ]
        case .coral:
            return [
                Color(red: 0.30, green: 0.16, blue: 0.18),
                Color(red: 0.36, green: 0.20, blue: 0.22),
                Color(red: 0.24, green: 0.12, blue: 0.14),
                Color(red: 0.10, green: 0.04, blue: 0.06)
            ]
        }
    }

    var radialColors: [Color] {
        switch self {
        case .ocean:
            return [
                Color(red: 0.10, green: 0.22, blue: 0.34),
                Color(red: 0.04, green: 0.12, blue: 0.20),
                Color(red: 0.02, green: 0.04, blue: 0.08)
            ]
        case .sunset:
            return [
                Color(red: 0.38, green: 0.20, blue: 0.18),
                Color(red: 0.26, green: 0.12, blue: 0.14),
                Color(red: 0.08, green: 0.02, blue: 0.04)
            ]
        case .forest:
            return [
                Color(red: 0.12, green: 0.28, blue: 0.18),
                Color(red: 0.06, green: 0.18, blue: 0.12),
                Color(red: 0.02, green: 0.06, blue: 0.04)
            ]
        case .lavender:
            return [
                Color(red: 0.26, green: 0.18, blue: 0.38),
                Color(red: 0.16, green: 0.10, blue: 0.26),
                Color(red: 0.06, green: 0.04, blue: 0.12)
            ]
        case .midnight:
            return [
                Color(red: 0.14, green: 0.14, blue: 0.22),
                Color(red: 0.08, green: 0.08, blue: 0.14),
                Color(red: 0.02, green: 0.02, blue: 0.06)
            ]
        case .coral:
            return [
                Color(red: 0.42, green: 0.24, blue: 0.26),
                Color(red: 0.28, green: 0.14, blue: 0.16),
                Color(red: 0.10, green: 0.04, blue: 0.06)
            ]
        }
    }

    var meshColors: [Color] {
        let colors = gradientColors
        let c1 = colors[0]
        let c2 = colors[1]
        let c3 = colors[2]
        let c4 = colors[3]
        return [
            c1, c2, c1,
            c2, c3, c2,
            c4, c3, c4
        ]
    }

    // Primary accent color for the theme (for icons, buttons)
    var accentColor: Color {
        switch self {
        case .ocean: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .sunset: return Color(red: 0.95, green: 0.6, blue: 0.4)
        case .forest: return Color(red: 0.4, green: 0.8, blue: 0.5)
        case .lavender: return Color(red: 0.7, green: 0.5, blue: 0.9)
        case .midnight: return Color(red: 0.5, green: 0.5, blue: 0.7)
        case .coral: return Color(red: 0.95, green: 0.5, blue: 0.5)
        }
    }
}

#Preview("Ocean") {
    AppGradient.background(for: .ocean)
}

#Preview("Sunset") {
    AppGradient.background(for: .sunset)
}

#Preview("Forest") {
    AppGradient.background(for: .forest)
}

#Preview("Lavender") {
    AppGradient.background(for: .lavender)
}

#Preview("Coral") {
    AppGradient.background(for: .coral)
}
