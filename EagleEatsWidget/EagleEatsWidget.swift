import WidgetKit
import SwiftUI

// MARK: - Widget Entry
// Shared data structure for timeline entries.

struct DiningWidgetEntry: TimelineEntry {
    let date: Date
    let flexBalance: Double
    let dailyBudget: Double
    let urgency: String
    let topHall: String
    let crowdLevel: String
}

// MARK: - Timeline Provider

struct DiningWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiningWidgetEntry {
        DiningWidgetEntry(
            date: Date(), flexBalance: 450.00, dailyBudget: 12.50,
            urgency: "healthy", topHall: "Bruceteria", crowdLevel: "Low"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DiningWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiningWidgetEntry>) -> Void) {
        let entry = DiningWidgetEntry(
            date: Date(),
            flexBalance: readBalance(),
            dailyBudget: readDailyBudget(),
            urgency: "healthy",
            topHall: "Bruceteria",
            crowdLevel: "Low"
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readBalance() -> Double {
        UserDefaults(suiteName: "group.com.eagleeats.shared")?.double(forKey: "flex_balance") ?? 0
    }

    private func readDailyBudget() -> Double {
        UserDefaults(suiteName: "group.com.eagleeats.shared")?.double(forKey: "daily_budget") ?? 0
    }
}

// MARK: - Balance Widget View

struct BalanceWidgetView: View {
    let entry: DiningWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
                Text("Dining Dollars")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Text("$\(String(format: "%.2f", entry.flexBalance))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                Text("$\(String(format: "%.2f", entry.dailyBudget))/day budget")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Widget Configuration

struct EagleEatsBalanceWidget: Widget {
    let kind: String = "EagleEatsBalance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DiningWidgetProvider()) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dining Balance")
        .description("View your current dining dollars balance and daily budget")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct EagleEatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        EagleEatsBalanceWidget()
    }
}
