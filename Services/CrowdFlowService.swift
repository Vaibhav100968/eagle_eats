import Foundation
import Combine

// MARK: - Crowd Level

enum CrowdLevel: String, Codable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"

    var tint: String {
        switch self {
        case .low:    return "34C759"
        case .medium: return "FF9500"
        case .high:   return "FF3B30"
        }
    }

    var icon: String {
        switch self {
        case .low:    return "person"
        case .medium: return "person.2"
        case .high:   return "person.3.fill"
        }
    }
}

// MARK: - Crowd Snapshot

struct CrowdSnapshot: Identifiable, Equatable {
    let id: String
    let hallId: String
    let score: Int
    let level: CrowdLevel
    let prediction: String
    let timestamp: Date

    static let empty = CrowdSnapshot(
        id: "empty", hallId: "", score: 0,
        level: .low, prediction: "", timestamp: Date()
    )
}

// MARK: - CrowdFlow Service
//
// Generates crowd level estimates for each dining hall based on:
//   1. Time of day (meal rush patterns)
//   2. Day of week (weekday vs weekend)
//   3. Hall-specific baseline capacity factors
//   4. Historical pattern simulation
//
// Scores are 0–100 where:
//   0–33  = Low
//   34–66 = Medium
//   67+   = High
//
// Predictions project the near-future trend (peaking, declining, etc.)
//
// NOTE: Uses simulated data. In production this would integrate
//       real-time occupancy sensors or card-swipe velocity.

@MainActor
final class CrowdFlowService: ObservableObject {

    static let shared = CrowdFlowService()

    @Published private(set) var snapshots: [String: CrowdSnapshot] = [:]

    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func refresh() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7
        let totalMinutes = hour * 60 + minute

        for hall in DiningHall.sampleHalls {
            let snap = computeSnapshot(
                for: hall, totalMinutes: totalMinutes,
                isWeekend: isWeekend, now: now
            )
            snapshots[hall.id] = snap
        }
    }

    func snapshot(for hallId: String) -> CrowdSnapshot {
        snapshots[hallId] ?? .empty
    }

    // MARK: - Computation

    private func computeSnapshot(
        for hall: DiningHall,
        totalMinutes: Int,
        isWeekend: Bool,
        now: Date
    ) -> CrowdSnapshot {
        let hours = isWeekend ? hall.weekendHours : hall.weekdayHours
        let openMin  = hours.openHour * 60 + hours.openMinute
        let closeMin = hours.closeHour * 60 + hours.closeMinute

        guard closeMin > openMin, totalMinutes >= openMin, totalMinutes < closeMin else {
            return CrowdSnapshot(
                id: "\(hall.id)-\(now.timeIntervalSince1970)",
                hallId: hall.id,
                score: 0,
                level: .low,
                prediction: "Closed",
                timestamp: now
            )
        }

        let baseScore = timeCurve(totalMinutes: totalMinutes, hallId: hall.id)
        let weekendFactor: Double = isWeekend ? 0.65 : 1.0
        let hallFactor = hallCapacityFactor(hall.id)
        let jitter = Double.random(in: -4...4)

        let raw = baseScore * weekendFactor * hallFactor + jitter
        let score = max(0, min(100, Int(raw)))

        let level: CrowdLevel
        switch score {
        case 0...33:  level = .low
        case 34...66: level = .medium
        default:      level = .high
        }

        let prediction = predictTrend(
            totalMinutes: totalMinutes, score: score,
            openMin: openMin, closeMin: closeMin
        )

        return CrowdSnapshot(
            id: "\(hall.id)-\(now.timeIntervalSince1970)",
            hallId: hall.id,
            score: score,
            level: level,
            prediction: prediction,
            timestamp: now
        )
    }

    // Simulates a bell-curve crowd pattern around known meal rush times
    private func timeCurve(totalMinutes: Int, hallId: String) -> Double {
        let peaks: [(center: Int, width: Double, height: Double)]

        switch hallId {
        case "bruceteria":
            peaks = [
                (center: 480, width: 50, height: 70),   // 8 AM breakfast
                (center: 720, width: 55, height: 90),   // noon lunch
            ]
        case "champs":
            peaks = [
                (center: 510, width: 40, height: 55),   // 8:30 AM
                (center: 750, width: 50, height: 80),   // 12:30 PM
                (center: 1080, width: 55, height: 75),  // 6 PM dinner
            ]
        case "eagle-landing":
            peaks = [
                (center: 720, width: 50, height: 85),   // noon
                (center: 1110, width: 50, height: 80),  // 6:30 PM
            ]
        case "kitchen-west":
            peaks = [
                (center: 750, width: 45, height: 65),   // 12:30 PM
                (center: 1050, width: 40, height: 55),  // 5:30 PM
            ]
        case "mean-greens":
            peaks = [
                (center: 480, width: 40, height: 50),   // 8 AM
                (center: 720, width: 50, height: 85),   // noon
                (center: 1080, width: 45, height: 70),  // 6 PM
            ]
        default:
            peaks = [(center: 720, width: 60, height: 75)]
        }

        var total = 5.0
        for peak in peaks {
            let dist = Double(totalMinutes - peak.center)
            let gauss = peak.height * exp(-(dist * dist) / (2.0 * peak.width * peak.width))
            total += gauss
        }
        return min(100, total)
    }

    private func hallCapacityFactor(_ hallId: String) -> Double {
        switch hallId {
        case "bruceteria":    return 1.1
        case "champs":        return 0.85
        case "eagle-landing": return 1.0
        case "kitchen-west":  return 0.75
        case "mean-greens":   return 0.9
        default:              return 1.0
        }
    }

    private func predictTrend(
        totalMinutes: Int, score: Int,
        openMin: Int, closeMin: Int
    ) -> String {
        let remaining = closeMin - totalMinutes

        if remaining <= 30 {
            return "Closing soon"
        }

        let futureScore = timeCurve(totalMinutes: totalMinutes + 20, hallId: "")
        let currentScore = Double(score)

        if futureScore > currentScore + 10 {
            let peakIn = estimateMinutesToPeak(from: totalMinutes)
            return "Peak in \(peakIn) min"
        } else if futureScore < currentScore - 10 {
            return "Crowd declining"
        }

        switch score {
        case 0...25:  return "Great time to visit"
        case 26...50: return "Moderate crowd"
        case 51...75: return "Getting busy"
        default:      return "Peak hours"
        }
    }

    private func estimateMinutesToPeak(from currentMinutes: Int) -> Int {
        let mealPeaks = [480, 720, 1080, 1110]
        var closest = 20
        for peak in mealPeaks {
            let diff = peak - currentMinutes
            if diff > 0 && diff < closest * 2 {
                closest = max(5, min(diff, 45))
            }
        }
        return closest
    }
}
