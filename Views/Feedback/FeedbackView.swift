import SwiftUI

// MARK: - Feedback View
// Apple-native list-based layout. No excessive cards or emojis.
// Accessed from Settings as a navigation link.

struct FeedbackView: View {
    @StateObject private var service = FeedbackService.shared
    @State private var showSubmit = false
    @State private var appeared = false

    var body: some View {
        List {
            // MARK: Ratings Overview
            if !service.summaries.isEmpty {
                Section {
                    ForEach(service.summaries) { summary in
                        HallRatingRow(summary: summary)
                    }
                } header: {
                    Text("Hall Ratings")
                }
            }

            // MARK: Recent Feedback
            Section {
                if service.entries.isEmpty {
                    ContentUnavailableView(
                        "No Feedback Yet",
                        systemImage: "text.bubble",
                        description: Text("Submit your first dining hall review")
                    )
                } else {
                    ForEach(service.entries.prefix(20)) { entry in
                        FeedbackEntryRow(entry: entry)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            service.delete(id: service.entries[index].id)
                        }
                    }
                }
            } header: {
                Text("Recent Reviews")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSubmit = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.untGreenPrimary)
                }
            }
        }
        .sheet(isPresented: $showSubmit) {
            NavigationStack {
                SubmitFeedbackView()
            }
        }
    }
}

// MARK: - Hall Rating Row

private struct HallRatingRow: View {
    let summary: HallRatingSummary

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.hallName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: Double(star) <= summary.averageRating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(Double(star) <= summary.averageRating
                                             ? Color(hex: "F59E0B") : Color.textTertiary)
                    }
                    Text(String(format: "%.1f", summary.averageRating))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.leading, 4)
                }

                if !summary.topTags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(summary.topTags) { tag in
                            HStack(spacing: 3) {
                                Image(systemName: tag.icon)
                                    .font(.system(size: 9))
                                Text(tag.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.surfaceRaised)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(summary.totalReviews)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.untGreenPrimary)
                Text("reviews")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Feedback Entry Row

private struct FeedbackEntryRow: View {
    let entry: FeedbackEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.hallName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(entry.date, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= entry.rating ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(star <= entry.rating
                                         ? Color(hex: "F59E0B") : Color.textTertiary)
                }
                Text(entry.mealPeriod)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.leading, 8)
            }

            if !entry.comment.isEmpty {
                Text(entry.comment)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(3)
            }

            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags) { tag in
                        Text(tag.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.untGreenPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.untGreenPrimary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Submit Feedback View

struct SubmitFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = FeedbackService.shared

    @State private var selectedHallId: String = DiningHall.sampleHalls.first?.id ?? ""
    @State private var selectedPeriod: String = MealPeriod.current().rawValue
    @State private var rating: Int = 4
    @State private var selectedTags: Set<FeedbackTag> = []
    @State private var comment: String = ""

    private var selectedHall: DiningHall? {
        DiningHall.sampleHalls.first { $0.id == selectedHallId }
    }

    var body: some View {
        Form {
            Section("Dining Hall") {
                Picker("Location", selection: $selectedHallId) {
                    ForEach(DiningHall.sampleHalls) { hall in
                        Text(hall.name).tag(hall.id)
                    }
                }

                Picker("Meal", selection: $selectedPeriod) {
                    ForEach([MealPeriod.breakfast, .lunch, .dinner], id: \.rawValue) { period in
                        Text(period.rawValue).tag(period.rawValue)
                    }
                }
            }

            Section("Rating") {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                rating = star
                            }
                            HapticService.shared.light()
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundStyle(star <= rating
                                                 ? Color(hex: "F59E0B") : Color.textTertiary)
                                .scaleEffect(star == rating ? 1.15 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: rating)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer()
                    Text(ratingLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.vertical, 4)
            }

            Section("Tags") {
                FlowLayout(spacing: 8) {
                    ForEach(FeedbackTag.allCases) { tag in
                        let isOn = selectedTags.contains(tag)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isOn { selectedTags.remove(tag) }
                                else { selectedTags.insert(tag) }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tag.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(tag.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isOn ? Color.untGreenPrimary : Color.surfaceRaised)
                            .foregroundStyle(isOn ? .white : Color.textSecondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Comment (optional)") {
                TextField("What did you think?", text: $comment, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.system(size: 15))
            }
        }
        .navigationTitle("Submit Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.textSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Submit") {
                    submitFeedback()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.untGreenPrimary)
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Below Average"
        case 3: return "Average"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return ""
        }
    }

    private func submitFeedback() {
        let hallName = selectedHall?.name ?? selectedHallId
        let entry = FeedbackEntry(
            hallId: selectedHallId,
            hallName: hallName,
            mealPeriod: selectedPeriod,
            rating: rating,
            tags: Array(selectedTags),
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        service.submit(entry)
        HapticService.shared.success()
        dismiss()
    }
}
