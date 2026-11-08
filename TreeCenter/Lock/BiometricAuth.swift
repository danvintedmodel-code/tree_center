import LocalAuthentication

// Face ID es la puerta rápida; el trazo es el respaldo.
// Si Face ID falla o está apagado, el trazo entra solo: nunca se cae a la nada.

enum BiometricAuth {
    enum Kind { case faceID, touchID, none }

    static var available: Kind {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    static var label: String {
        switch available {
        case .faceID: return "Usar Face ID"
        case .touchID: return "Usar Touch ID"
        case .none: return "Biometría no disponible"
        }
    }

    /// Devuelve true solo si el sistema confirma la identidad.
    /// Un error nunca abre la app: cualquier fallo es un "no".
    static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""   // sin "usar código": aquí el respaldo es el trazo

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Entrar en Tree Center"
            )
        } catch {
            return false
        }
    }
}
