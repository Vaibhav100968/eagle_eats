import SwiftUI

// MARK: - UNT Eagle Eats Design System Colors
// Adaptive colors that work in both light and dark mode.

extension Color {

    // MARK: UNT Green Palette (static, same in both modes)
    static let untGreenPrimary   = Color(hex: "00853E")
    static let untGreenDark      = Color(hex: "005227")
    static let untGreenDeep      = Color(hex: "003D1F")
    static let untGreenMedium    = Color(hex: "1A9E4E")
    static let untGreenLight     = Color(hex: "34C068")
    static let untGreenSoft      = Color(hex: "5ED68A")
    static let untGreenMint      = Color(hex: "A3E8BE")
    static let untGreenPale      = Color(hex: "D4F4E4")

    // MARK: Adaptive Surfaces
    static let untGreenBackground = Color("untGreenBackground", bundle: nil)
        .ifUnavailable(light: "F0FAF4", dark: "0D1117")
    static let surfaceBase = Color("surfaceBase", bundle: nil)
        .ifUnavailable(light: "FFFFFF", dark: "161B22")
    static let surfaceRaised = Color("surfaceRaised", bundle: nil)
        .ifUnavailable(light: "F7F7F7", dark: "1C2128")
    static let surfaceCard = Color("surfaceCard", bundle: nil)
        .ifUnavailable(light: "FAFAFA", dark: "1C2128")
    static let surfaceOverlay = Color("surfaceOverlay", bundle: nil)
        .ifUnavailable(light: "F2F8F4", dark: "162217")

    // MARK: Adaptive Text
    static let textPrimary = Color("textPrimary", bundle: nil)
        .ifUnavailable(light: "111827", dark: "E6EDF3")
    static let textSecondary = Color("textSecondary", bundle: nil)
        .ifUnavailable(light: "6B7280", dark: "8B949E")
    static let textTertiary = Color("textTertiary", bundle: nil)
        .ifUnavailable(light: "9CA3AF", dark: "6E7681")
    static let textInverse       = Color(hex: "FFFFFF")

    // MARK: Adaptive Borders
    static let borderSubtle = Color("borderSubtle", bundle: nil)
        .ifUnavailable(light: "E5E7EB", dark: "30363D")
    static let borderMedium = Color("borderMedium", bundle: nil)
        .ifUnavailable(light: "D1D5DB", dark: "484F58")

    // MARK: Status Colors
    static let statusOpen        = Color(hex: "00853E")
    static let statusClosed      = Color(hex: "EF4444")
    static let statusWarning     = Color(hex: "F59E0B")

    // MARK: Macro Colors
    static let macroCalories     = Color(hex: "FF6B6B")
    static let macroProtein      = Color(hex: "00853E")
    static let macroCarbs        = Color(hex: "3B82F6")
    static let macroFat          = Color(hex: "F59E0B")
    static let macroFiber        = Color(hex: "8B5CF6")

    // MARK: Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    /// Fallback for named colors: uses light/dark hex pairs when asset catalog colors are absent.
    static func ifUnavailable(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}

extension Color {
    /// Instance version for chaining.
    func ifUnavailable(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}

// MARK: - Gradient Presets

extension LinearGradient {
    static let untHeroGradient = LinearGradient(
        colors: [.untGreenDeep, .untGreenDark, .untGreenPrimary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let untCardGradient = LinearGradient(
        colors: [.untGreenPrimary.opacity(0.9), .untGreenDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let untSubtleGradient = LinearGradient(
        colors: [.untGreenBackground, .surfaceBase],
        startPoint: .top,
        endPoint: .bottom
    )
    static let macroRingBackground = LinearGradient(
        colors: [Color.untGreenBackground, Color.surfaceOverlay],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Shimmer Loading Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: phase - 0.3),
                            .init(color: .white.opacity(0.55), location: phase),
                            .init(color: .clear, location: phase + 0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + geo.size.width * 2 * phase)
                    .clipped()
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
