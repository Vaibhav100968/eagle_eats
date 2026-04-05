import SwiftUI

// MARK: - Eagle Eats Typography System
// Uses SF Pro with Rounded design variant for warmth + premium feel

extension Font {

    // MARK: Display — Hero headings, splash screens
    static let displayLarge  = Font.system(size: 52, weight: .bold,    design: .rounded)
    static let displayMedium = Font.system(size: 40, weight: .bold,    design: .rounded)
    static let displaySmall  = Font.system(size: 32, weight: .semibold, design: .rounded)

    // MARK: Heading
    static let headingXL     = Font.system(size: 28, weight: .bold,    design: .default)
    static let headingLarge  = Font.system(size: 24, weight: .semibold, design: .default)
    static let headingMedium = Font.system(size: 20, weight: .semibold, design: .default)
    static let headingSmall  = Font.system(size: 17, weight: .semibold, design: .default)

    // MARK: Body
    static let bodyLarge     = Font.system(size: 17, weight: .regular,  design: .default)
    static let bodyMedium    = Font.system(size: 15, weight: .regular,  design: .default)
    static let bodySmall     = Font.system(size: 13, weight: .regular,  design: .default)

    // MARK: Label / Utility
    static let labelLarge    = Font.system(size: 15, weight: .medium,   design: .default)
    static let labelMedium   = Font.system(size: 13, weight: .medium,   design: .default)
    static let labelSmall    = Font.system(size: 11, weight: .medium,   design: .default)
    static let caption       = Font.system(size: 11, weight: .regular,  design: .default)

    // MARK: Numeric / Macro (Rounded for a clean stat look)
    static let numberHuge    = Font.system(size: 44, weight: .bold,    design: .rounded)
    static let numberLarge   = Font.system(size: 28, weight: .bold,    design: .rounded)
    static let numberMedium  = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let numberSmall   = Font.system(size: 15, weight: .semibold, design: .rounded)
}

// MARK: - View Modifier: Tracking helpers

struct TrackingModifier: ViewModifier {
    let tracking: CGFloat
    func body(content: Content) -> some View {
        content.tracking(tracking)
    }
}

extension View {
    func letterSpacing(_ tracking: CGFloat) -> some View {
        modifier(TrackingModifier(tracking: tracking))
    }
}
