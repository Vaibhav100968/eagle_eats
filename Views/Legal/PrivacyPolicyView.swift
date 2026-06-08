import SwiftUI

// MARK: - Privacy Policy (in-app, Guideline 5.1.1)

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AffiliationDisclaimerView()

                Group {
                    sectionTitle("Overview")
                    bodyText("""
                    Mean Eats helps UNT students browse dining hall menus, track nutrition, and manage meal plan information. This policy describes what data we collect, how we use it, and your choices.
                    """)

                    sectionTitle("Data We Collect")
                    bodyText("""
                    • Account: Display name and session state after you sign in through UNT's official meal plan portal (we do not store your UNT password).
                    • Guest use: If you continue without signing in, we assign an anonymous device guest ID stored on your device to count usage.
                    • Usage analytics: We send anonymous app events (e.g. app launch, screen views) to our backend. Events include a guest ID or auth user ID, event type, and optional metadata. We do not use cross-app advertising trackers or sell this data.
                    • Dining activity: Meals you log, nutrition goals, favorites, and settings stored on your device.
                    • Optional location: Used only to show nearest dining halls when you grant permission.
                    • Photos: Only when you choose to add a photo to a menu item review.
                    • Feedback & reports: Dining feedback and content reports you submit.
                    """)

                    sectionTitle("Third Parties")
                    bodyText("""
                    • UNT meal plan portal: Authentication happens on UNT's website in a secure web view.
                    • Supabase: Menu data, anonymous usage events, and optional features are stored on Supabase using the anonymous API key configured in our backend.
                    • UNT dining websites: Public menu information is aggregated by our backend scraper for display in the app.
                    We do not sell your personal data. Third parties must protect data consistent with this policy.
                    """)

                    sectionTitle("Retention & Deletion")
                    bodyText("""
                    Most data is stored on your device. You can delete your account from Settings, which clears local credentials and session data. Anonymous usage events on our servers are retained for analytics and may be linked to your auth user ID if you later sign in. Contact us to request deletion of server data tied to you.
                    """)

                    sectionTitle("Children")
                    bodyText("""
                    Mean Eats is intended for UNT students and is not directed at children under 13. We do not knowingly collect data from children.
                    """)

                    sectionTitle("Contact")
                    bodyText("Questions or deletion requests: \(AppSupport.supportEmail)")
                }
            }
            .padding(20)
        }
        .background(Color.untGreenBackground.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
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
