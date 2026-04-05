import UIKit

// MARK: - Haptic Service
// Centralized haptic feedback using UIKit generators.
// Call sites: tab selection, meal save, feedback submit, hall selection.

final class HapticService {

    static let shared = HapticService()
    private init() {}

    private let lightGen   = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen  = UIImpactFeedbackGenerator(style: .medium)
    private let notifGen   = UINotificationFeedbackGenerator()
    private let selectGen  = UISelectionFeedbackGenerator()

    func light() {
        lightGen.impactOccurred()
    }

    func medium() {
        mediumGen.impactOccurred()
    }

    func selection() {
        selectGen.selectionChanged()
    }

    func success() {
        notifGen.notificationOccurred(.success)
    }

    func warning() {
        notifGen.notificationOccurred(.warning)
    }

    func error() {
        notifGen.notificationOccurred(.error)
    }

    func prepare() {
        lightGen.prepare()
        mediumGen.prepare()
        notifGen.prepare()
    }
}
