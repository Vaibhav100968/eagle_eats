import Foundation
import CoreLocation

// MARK: - Context Engine
// Real-time decision engine that recommends the best dining option
// for the next 30–60 minutes based on current context.
//
// Inputs: time, location, crowd, distance, meal period, budget urgency
// Output: a ranked ContextRecommendation with explanation

@MainActor
final class ContextEngine: ObservableObject {

    static let shared = ContextEngine()

    @Published private(set) var recommendation: ContextRecommendation?

    private let dining   = DiningService.shared
    private let crowd    = CrowdFlowService.shared
    private let budget   = BudgetEngine.shared
    private let location = LocationService.shared

    private init() {}

    // MARK: - Weights

    private struct W {
        static let openNow:   Double = 30
        static let crowdLow:  Double = 25
        static let proximity: Double = 20
        static let budget:    Double = 15
        static let variety:   Double = 10
    }

    // MARK: - Compute

    func evaluate() {
        let period = MealPeriod.current()
        guard period != .closed else {
            recommendation = nil
            return
        }

        var candidates: [(DiningHall, Double, [ContextFactor])] = []

        for hall in dining.halls {
            var score: Double = 0
            var factors: [ContextFactor] = []

            // 1. Open status
            if hall.isOpen {
                score += W.openNow
                factors.append(.init(icon: "clock.fill", text: "Open now", impact: .positive))
            } else {
                continue
            }

            // 2. Crowd level
            let snapshot = crowd.snapshot(for: hall.id)
            switch snapshot.level {
            case .low:
                score += W.crowdLow
                factors.append(.init(icon: "person", text: "Low crowd", impact: .positive))
            case .medium:
                score += W.crowdLow * 0.5
                factors.append(.init(icon: "person.2", text: "Moderate crowd", impact: .neutral))
            case .high:
                score -= 5
                factors.append(.init(icon: "person.3.fill", text: "Crowded right now", impact: .negative))
            }

            // 3. Distance
            if let userLoc = location.currentLocation {
                let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                let dest = CLLocation(latitude: hall.latitude, longitude: hall.longitude)
                let meters = user.distance(from: dest)
                let walkMinutes = meters / 80.0 // ~80m/min walking

                if walkMinutes <= 5 {
                    score += W.proximity
                    factors.append(.init(icon: "figure.walk", text: "\(Int(walkMinutes)) min walk", impact: .positive))
                } else if walkMinutes <= 10 {
                    score += W.proximity * 0.6
                    factors.append(.init(icon: "figure.walk", text: "\(Int(walkMinutes)) min walk", impact: .neutral))
                } else {
                    score += W.proximity * 0.2
                    factors.append(.init(icon: "figure.walk", text: "\(Int(walkMinutes)) min walk", impact: .negative))
                }
            }

            // 4. Budget consciousness
            if budget.snapshot.urgency == .critical || budget.snapshot.urgency == .warning {
                let items = dining.menuItems(for: hall, period: period)
                let swipeHalls: Set<String> = ["bruceteria", "eagle-landing", "champs", "kitchen-west", "mean-greens"]
                if swipeHalls.contains(hall.id) {
                    score += W.budget
                    factors.append(.init(icon: "dollarsign.circle", text: "Use a swipe — save flex", impact: .positive))
                }
            } else {
                score += W.budget * 0.5
            }

            // 5. Menu variety
            let items = dining.menuItems(for: hall, period: period)
            let varietyScore = min(Double(items.count) / 25.0, 1.0) * W.variety
            score += varietyScore
            if items.count > 15 {
                factors.append(.init(icon: "square.grid.2x2", text: "\(items.count) items available", impact: .positive))
            }

            candidates.append((hall, score, factors))
        }

        guard let best = candidates.max(by: { $0.1 < $1.1 }) else {
            recommendation = nil
            return
        }

        let timeWindow: String
        let now = Calendar.current.component(.minute, from: Date())
        if now < 30 {
            timeWindow = "Best option for the next 30 min"
        } else {
            timeWindow = "Best option right now"
        }

        recommendation = ContextRecommendation(
            hall: best.0,
            score: min(100, max(0, best.1)),
            factors: best.2,
            timeWindow: timeWindow,
            computedAt: Date()
        )
    }
}

// MARK: - Context Recommendation

struct ContextRecommendation: Identifiable {
    let id = UUID()
    let hall: DiningHall
    let score: Double
    let factors: [ContextFactor]
    let timeWindow: String
    let computedAt: Date
}

struct ContextFactor: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let impact: ContextImpact
}

enum ContextImpact {
    case positive, neutral, negative

    var tint: String {
        switch self {
        case .positive: return "34C759"
        case .neutral:  return "FF9500"
        case .negative: return "FF3B30"
        }
    }
}
