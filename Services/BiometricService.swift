import LocalAuthentication
import Foundation

// MARK: - Biometric Service
// Wraps LAContext for Face ID / Touch ID quick re-authentication.
// Used for sensitive actions like viewing spending history or exporting data.

@MainActor
final class BiometricService: ObservableObject {

    static let shared = BiometricService()

    @Published private(set) var biometryType: LABiometryType = .none
    @Published private(set) var isAvailable: Bool = false

    private init() {
        checkAvailability()
    }

    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometryType = context.biometryType
    }

    var biometryName: String {
        switch biometryType {
        case .faceID:    return "Face ID"
        case .touchID:   return "Touch ID"
        case .opticID:   return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

    var biometryIcon: String {
        switch biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
