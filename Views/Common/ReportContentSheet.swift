import SwiftUI

struct ReportContentSheet: View {
    let contentType: ReportableContentType
    let contentId: String
    var reportedUserName: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var didSubmit = false

    private let reasons = [
        "Spam or misleading",
        "Offensive or inappropriate",
        "Harassment",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                if didSubmit {
                    Section {
                        Label("Report submitted. We'll review it promptly.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.untGreenPrimary)
                    }
                } else {
                    Section("Why are you reporting this?") {
                        ForEach(reasons, id: \.self) { option in
                            Button(option) {
                                reason = option
                                submit(option)
                            }
                        }
                    }
                    Section {
                        Text("Contact: \(AppSupport.supportEmail)")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func submit(_ selected: String) {
        ContentModerationService.shared.submitReport(
            type: contentType,
            contentId: contentId,
            reason: selected
        )
        if let name = reportedUserName, !name.isEmpty {
            // Offer block via separate UI; report is recorded
        }
        didSubmit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }
}
