import SwiftUI

struct HealthDisclaimerView: View {
    var body: some View {
        ScrollView {
            Text("""
            Nutrition information in Eagle Eats comes from UNT dining menus and labels. Values are estimates and may vary by serving.

            Eagle Eats is for informational purposes only. It is not medical advice and is not intended to diagnose, treat, or prevent any condition. Talk to a healthcare professional before making medical or dietary decisions.
            """)
            .font(.system(size: 14))
            .foregroundStyle(Color.textSecondary)
            .lineSpacing(4)
            .padding(20)
        }
        .background(Color.untGreenBackground.ignoresSafeArea())
        .navigationTitle("Health Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}
