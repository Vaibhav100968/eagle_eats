import SwiftUI

// MARK: - Best Option Card
// "Best dining hall right now" recommendation displayed at the top of HomeView.
// Shows the top-ranked hall with reasons and a peek at recommended items.

struct BestOptionCard: View {
    let recommendation: HallRecommendation
    var onSelectHall: ((DiningHall) -> Void)? = nil
    var onSelectItem: ((MenuItem) -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.untGreenPrimary)
                Text("Best Option Right Now")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.untGreenPrimary)
                    .textCase(.uppercase)
                    .letterSpacing(0.6)
                Spacer()
                Text("Score: \(Int(recommendation.score))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
            }

            // Hall card
            Button(action: { onSelectHall?(recommendation.hall) }) {
                HStack(spacing: 14) {
                    // Hall icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: recommendation.hall.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: recommendation.hall.iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(recommendation.hall.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.textPrimary)

                        // Reason chips
                        HStack(spacing: 6) {
                            ForEach(recommendation.reasons.prefix(3), id: \.displayText) { reason in
                                HStack(spacing: 4) {
                                    Image(systemName: reason.icon)
                                        .font(.system(size: 9, weight: .bold))
                                    Text(reason.displayText)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundStyle(reason.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(reason.color.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(16)
                .background(Color.surfaceBase)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(DiningCardButtonStyle())

            // Top recommended items peek
            if !recommendation.topItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Picks")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSecondary)
                        .textCase(.uppercase)
                        .letterSpacing(0.5)
                        .padding(.leading, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recommendation.topItems.prefix(4)) { scored in
                                RecommendedItemChip(
                                    item: scored.item,
                                    reasons: scored.reasons,
                                    hallColor: Color(hex: recommendation.hall.gradientStart)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Recommended Item Chip

private struct RecommendedItemChip: View {
    let item: MenuItem
    let reasons: [RecommendationReason]
    let hallColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            if item.nutritionLoaded && item.nutrition.isComplete {
                HStack(spacing: 6) {
                    Text("\(Int(item.nutrition.calories)) cal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.macroCalories)
                    Text("P:\(Int(item.nutrition.protein))g")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.macroProtein)
                }
            }

            if let reason = reasons.first {
                HStack(spacing: 3) {
                    Image(systemName: reason.icon)
                        .font(.system(size: 8, weight: .bold))
                    Text(reason.displayText)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(reason.color)
            }
        }
        .padding(12)
        .frame(width: 140, alignment: .leading)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(hallColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}
