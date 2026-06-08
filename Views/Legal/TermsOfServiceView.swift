import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AffiliationDisclaimerView()

                Group {
                    sectionTitle("Agreement")
                    bodyText("""
                    By using Mean Eats, you agree to these Terms of Service. If you do not agree, do not use the app.
                    """)

                    sectionTitle("Service Description")
                    bodyText("""
                    Mean Eats provides dining hall menus, nutrition estimates, meal tracking tools, and optional UNT meal plan portal access. Menu and nutrition data come from public UNT dining sources and are provided for convenience only — not as official UNT communications.
                    """)

                    sectionTitle("Accounts & Guest Use")
                    bodyText("""
                    You may browse as a guest or sign in through UNT's official meal plan portal. You are responsible for activity on your device. We do not store your UNT password.
                    """)

                    sectionTitle("User Content")
                    bodyText("""
                    If you submit feedback, photos, or other content, you grant us a limited license to display and process that content to operate the app. Do not post unlawful, harassing, or infringing content. We may remove content that violates these terms.
                    """)

                    sectionTitle("No Medical Advice")
                    bodyText("""
                    Nutrition information is estimated. Mean Eats is not medical advice. See the Health Disclaimer in Settings for details.
                    """)

                    sectionTitle("Disclaimer of Warranties")
                    bodyText("""
                    Mean Eats is provided "as is" without warranties. We do not guarantee menu accuracy, availability, or uninterrupted service.
                    """)

                    sectionTitle("Limitation of Liability")
                    bodyText("""
                    To the fullest extent permitted by law, Mean Eats and its developers are not liable for indirect or consequential damages arising from use of the app.
                    """)

                    sectionTitle("Changes")
                    bodyText("""
                    We may update these terms. Continued use after changes constitutes acceptance of the updated terms.
                    """)

                    sectionTitle("Contact")
                    bodyText("Questions: \(AppSupport.supportEmail)")
                }
            }
            .padding(20)
        }
        .background(Color.untGreenBackground.ignoresSafeArea())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color.textPrimary)
    }

    private func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Color.textSecondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}
