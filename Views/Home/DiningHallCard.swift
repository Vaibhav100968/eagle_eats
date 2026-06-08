import SwiftUI

// MARK: - Dining Hall Card
// onSelect is injected by the parent (HomeView) and attached via a real Button
// wrapper — NOT via _onButtonGesture which consumed taps silently.

struct DiningHallCard: View {
    let hall:      DiningHall
    var isCompact: Bool       = false
    var onSelect:  (() -> Void)? = nil

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var diningService: DiningService
    @StateObject private var crowdFlow = CrowdFlowService.shared
    @StateObject private var locationService = LocationService.shared

    private var distanceText: String? {
        guard let meters = locationService.distance(to: hall) else { return nil }
        return MapService.formattedDistance(meters: meters)
    }

    private var isOpenNow: Bool { diningService.isHallOpen(hall) }

    var body: some View {
        if isCompact {
            compactCard
        } else {
            fullCard
        }
    }

    // MARK: - Full Card

    private var fullCard: some View {
        Button(action: { HapticService.shared.light(); onSelect?() }) {
            ZStack(alignment: .bottomLeading) {
                // Background gradient
                LinearGradient(
                    colors: hall.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Depth overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.38)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Decorative circles
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 180)
                    .offset(x: 120, y: -50)
                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 120)
                    .offset(x: 160, y: 20)

                // Content row
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Tag chips
                        HStack(spacing: 6) {
                            ForEach(hall.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }

                        // Name + subtitle
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hall.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(hall.subtitle)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }

                        // Hours + Crowd
                        HStack(spacing: 12) {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11))
                                Text(isOpenNow ? todayHoursDisplay : "Closed Today")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.7))

                            if isOpenNow {
                                let snap = crowdFlow.snapshot(for: hall.id)
                                HStack(spacing: 5) {
                                    Image(systemName: snap.level.icon)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("\(snap.level.rawValue)")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: snap.level.tint).opacity(0.6))
                                .clipShape(Capsule())
                            }
                        }

                        // View Menu + Distance
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Text("View Menu")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))

                            if let dist = distanceText {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 10))
                                    Text(dist)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        FavoriteButton(hallId: hall.id)
                        OpenClosedBadge(isOpen: isOpenNow, period: hall.currentMealPeriod)
                        Image(systemName: hall.iconName)
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(20)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color(hex: hall.gradientStart).opacity(0.35), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(DiningCardButtonStyle())
    }

    // MARK: - Compact Card

    private var compactCard: some View {
        Button(action: { HapticService.shared.light(); onSelect?() }) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: hall.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    OpenClosedBadge(isOpen: isOpenNow, period: hall.currentMealPeriod)
                    Text(hall.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(hall.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(14)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color(hex: hall.gradientStart).opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(DiningCardButtonStyle())
    }

    private var todayHoursDisplay: String {
        let calendar = Calendar.current
        let isWeekend = [1, 7].contains(calendar.component(.weekday, from: Date()))
        let hours = isWeekend ? hall.weekendHours : hall.weekdayHours
        if hours.openHour == 0 && hours.closeHour == 0 { return "Closed today" }
        return hours.displayString
    }
}

// MARK: - Card Button Style (spring press, no default highlight)

struct DiningCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Open/Closed Badge

struct OpenClosedBadge: View {
    let isOpen:  Bool
    let period:  MealPeriod
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 5) {
            if isOpen {
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulsing ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulsing)
            }
            Text(isOpen ? period.rawValue : "Closed")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isOpen ? period.color : Color(hex: "EF4444").opacity(0.85))
        .clipShape(Capsule())
        .onAppear { if isOpen { pulsing = true } }
    }
}

// MARK: - Favorite Button

struct FavoriteButton: View {
    let hallId: String
    @EnvironmentObject private var appState: AppState
    @State private var bouncing = false

    var isFav: Bool { appState.isFavorite(hallId) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                bouncing = true
                appState.toggleFavorite(hallId: hallId)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bouncing = false }
            }
        } label: {
            Image(systemName: isFav ? "star.fill" : "star")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFav ? Color(hex: "FBBF24") : .white.opacity(0.7))
                .scaleEffect(bouncing ? 1.4 : 1.0)
                .contentTransition(.symbolEffect(.replace.downUp))
                .padding(8)
                .background(.black.opacity(0.2))
                .clipShape(Circle())
        }
    }
}
