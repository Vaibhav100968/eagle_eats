import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct DiningWidgetEntry: TimelineEntry {
    let date: Date
    let mealPeriod: String
    let menuItems: [WidgetMenuItem]
    let hallStatuses: [WidgetHallStatus]
    let flexBalance: Double
    let dailyBudget: Double
}

// MARK: - Timeline Provider

struct DiningWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DiningWidgetEntry {
        DiningWidgetEntry(
            date: Date(),
            mealPeriod: "Lunch",
            menuItems: [
                WidgetMenuItem(id: "1", name: "Grilled Chicken", hallName: "Bruceteria", calories: 350, station: "Grill"),
                WidgetMenuItem(id: "2", name: "Caesar Salad", hallName: "Mean Greens", calories: 220, station: "Salad Bar"),
                WidgetMenuItem(id: "3", name: "Pasta Marinara", hallName: "Eagle Landing", calories: 450, station: "Pasta"),
            ],
            hallStatuses: [
                WidgetHallStatus(id: "bruceteria", name: "Bruceteria", isOpen: true, mealPeriod: "Lunch"),
                WidgetHallStatus(id: "mean-greens", name: "Mean Greens", isOpen: true, mealPeriod: "Lunch"),
            ],
            flexBalance: 450.00,
            dailyBudget: 12.50
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DiningWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiningWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> DiningWidgetEntry {
        DiningWidgetEntry(
            date: Date(),
            mealPeriod: WidgetSnapshot.mealPeriod(),
            menuItems: [],
            hallStatuses: WidgetSnapshot.hallStatuses(),
            flexBalance: 0,
            dailyBudget: 0
        )
    }
}

// MARK: - Today's Menu Widget View

struct TodayMenuWidgetView: View {
    let entry: DiningWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0, green: 0.52, blue: 0.24))
                Text(entry.mealPeriod)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if entry.menuItems.isEmpty {
                Text("Open Mean Eats for live menus")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.menuItems.prefix(3)) { item in
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.calories)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            let openCount = entry.hallStatuses.filter(\.isOpen).count
            Text("\(openCount) hall\(openCount == 1 ? "" : "s") open")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: Menu items
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0, green: 0.52, blue: 0.24))
                    Text("Today's \(entry.mealPeriod)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if entry.menuItems.isEmpty {
                    Text("Open Mean Eats for live menus")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.menuItems.prefix(4)) { item in
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.calories) cal")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Hall statuses
            VStack(alignment: .leading, spacing: 6) {
                Text("Halls")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)

                ForEach(entry.hallStatuses.prefix(4)) { hall in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(hall.isOpen ? Color.green : Color.red.opacity(0.6))
                            .frame(width: 6, height: 6)
                        Text(hall.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 100)
        }
        .padding()
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

// MARK: - Widget Configurations

struct EagleEatsTodayWidget: Widget {
    let kind: String = "EagleEatsToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DiningWidgetProvider()) { entry in
            TodayMenuWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Menu")
        .description("See what's being served right now at UNT dining halls")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EagleEatsBalanceWidget: Widget {
    let kind: String = "EagleEatsBalance"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DiningWidgetProvider()) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dining Balance")
        .description("View your current dining dollars balance and daily budget")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle

@main
struct EagleEatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        EagleEatsTodayWidget()
        EagleEatsBalanceWidget()
    }
}
