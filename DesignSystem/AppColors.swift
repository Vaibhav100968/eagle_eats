import SwiftUI

// MARK: - UNT Eagle Eats Design System Colors

extension Color {

    // MARK: UNT Green Palette
    static let untGreenPrimary   = Color(hex: "00853E")   // Official UNT Green
    static let untGreenDark      = Color(hex: "005227")   // Deep Forest
    static let untGreenDeep      = Color(hex: "003D1F")   // Darkest anchor
    static let untGreenMedium    = Color(hex: "1A9E4E")   // Vibrant mid-tone
    static let untGreenLight     = Color(hex: "34C068")   // Bright leaf
    static let untGreenSoft      = Color(hex: "5ED68A")   // Soft lime
    static let untGreenMint      = Color(hex: "A3E8BE")   // Pale mint
    static let untGreenPale      = Color(hex: "D4F4E4")   // Whisper green
    static let untGreenBackground = Color(hex: "F0FAF4")  // App surface tint

    // MARK: Semantic Surfaces
    static let surfaceBase       = Color(hex: "FFFFFF")
    static let surfaceRaised     = Color(hex: "F7F7F7")
    static let surfaceCard       = Color(hex: "FAFAFA")
    static let surfaceOverlay    = Color(hex: "F2F8F4")

    // MARK: Text
    static let textPrimary       = Color(hex: "111827")
    static let textSecondary     = Color(hex: "6B7280")
    static let textTertiary      = Color(hex: "9CA3AF")
    static let textInverse       = Color(hex: "FFFFFF")

    // MARK: Borders & Dividers
    static let borderSubtle      = Color(hex: "E5E7EB")
    static let borderMedium      = Color(hex: "D1D5DB")

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
        colors: [Color(hex: "F0FAF4"), Color(hex: "E8F5EE")],
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
