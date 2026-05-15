import SwiftUI

// MARK: - Menu Trends View

struct MenuTrendsView: View {
    @StateObject private var historyService = MenuHistoryService.shared
    @State private var selectedTab: TrendsTab = .predictions
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.untGreenBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        tabPicker
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        switch selectedTab {
                        case .predictions:
                            predictionsSection
                        case .trending:
                            trendingSection
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Menu Trends")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                historyService.computeTrends()
                withAnimation(.spring(response: 0.5).delay(0.1)) { appeared = true }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(TrendsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Color.untGreenPrimary : Color.clear)
                    .foregroundStyle(selectedTab == tab ? .white : Color.textSecondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.surfaceBase)
        .clipShape(Capsule())
    }

    // MARK: - Predictions

    private var predictionsSection: some View {
        VStack(spacing: 16) {
            if historyService.predictions.isEmpty {
                emptyState(
                    icon: "crystal.ball",
                    title: "No Predictions Yet",
                    message: "Keep using Eagle Eats daily — after a few days, we'll start predicting tomorrow's menu based on patterns."
                )
            } else {
                // Group by hall
                let grouped = Dictionary(grouping: historyService.predictions, by: \.hallName)
                ForEach(Array(grouped.keys.sorted()), id: \.self) { hallName in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.untGreenPrimary)
                            Text(hallName)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("Tomorrow")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal, 20)

                        ForEach(grouped[hallName] ?? []) { prediction in
                            PredictionRow(prediction: prediction)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color.surfaceBase)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Trending

    private var trendingSection: some View {
        VStack(spacing: 12) {
            if historyService.trendingItems.isEmpty {
                emptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Trends Yet",
                    message: "Menu trends will appear here after the app has tracked menus for a few days."
                )
            } else {
                ForEach(Array(historyService.trendingItems.enumerated()), id: \.element.id) { index, item in
                    TrendingItemRow(item: item, rank: index + 1)
                }
                .padding(.horizontal, 16)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.untGreenPale)
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.untGreenPrimary)
            }
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Prediction Row

private struct PredictionRow: View {
    let prediction: MenuPrediction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(prediction.itemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if !prediction.station.isEmpty {
                    Text(prediction.station)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text(prediction.confidenceLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: prediction.confidenceColor))

                Text("\(Int(prediction.probability * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: prediction.confidenceColor))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}

// MARK: - Trending Item Row

private struct TrendingItemRow: View {
    let item: TrendingItem
    let rank: Int

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(rank <= 3 ? Color.untGreenPrimary : Color.textTertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(item.hallName, systemImage: "building.2")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)

                    if let pattern = item.pattern {
                        Text("•")
                            .foregroundStyle(Color.textTertiary)
                        Text(pattern)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "F59E0B"))
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.appearances)x")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text("seen")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Trends Tab

private enum TrendsTab: String, CaseIterable {
    case predictions = "Predictions"
    case trending    = "Trending"

    var icon: String {
        switch self {
        case .predictions: return "sparkles"
        case .trending:    return "chart.line.uptrend.xyaxis"
        }
    }
}
