import SwiftUI

// MARK: - UNT Affiliation Disclaimer (App Store Guideline — avoid misleading affiliation)

struct AffiliationDisclaimerView: View {
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
            Text(AppSupport.affiliationDisclaimer)
                .font(.system(size: compact ? 11 : 13, weight: .medium))
                .foregroundStyle(compact ? Color.textTertiary : Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
