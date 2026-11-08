import CoreGraphics
import Foundation
import Observation
import TreeCenterCore

// El estado de la puerta. Nada de la app se carga hasta que esto dice `unlocked`.

@MainActor
@Observable
public final class LockController {

    public enum Phase: Equatable {
        /// No hay trazo guardado todavía: hay que grabarlo.
        case enrollFirst
        /// Ya dibujaste uno; falta repetirlo para confirmar.
        case enrollConfirm
        /// Hay trazo guardado y estamos pidiéndolo.
        case locked
        case unlocked
    }

    public private(set) var phase: Phase
    private(set) var message: String?
    private(set) var isError = false
    private(set) var failedAttempts = 0
    private(set) var lockedUntil: Date?

    var tolerance: StrokeTolerance = .normal

    private var pendingFirstDraw: StrokePattern?

    /// Fallos seguidos antes de hacer esperar.
    private let maxAttempts = 3
    private let penalty: TimeInterval = 30

    public init() {
        phase = LockStore.hasPattern ? .locked : .enrollFirst
        tolerance = LockStore.load()?.tolerance ?? .normal
    }

    var isWaitingOutPenalty: Bool {
        guard let lockedUntil else { return false }
        return lockedUntil > .now
    }

    var secondsLeft: Int {
        guard let lockedUntil else { return 0 }
        return max(0, Int(lockedUntil.timeIntervalSinceNow.rounded(.up)))
    }

    var canDraw: Bool { phase != .unlocked && !isWaitingOutPenalty }

    // MARK: - Dibujo terminado

    func handle(_ raw: [[CGPoint]]) {
        guard canDraw else { return }

        guard let drawn = StrokeMatcher.normalise(raw) else {
            fail("Eso no llega a trazo. Dibújalo más grande.")
            return
        }

        switch phase {
        case .enrollFirst:
            pendingFirstDraw = drawn
            phase = .enrollConfirm
            message = "Ahora dibújalo otra vez igual."
            isError = false

        case .enrollConfirm:
            guard let first = pendingFirstDraw else {
                phase = .enrollFirst
                return
            }
            if StrokeMatcher.matches(drawn, template: first, tolerance: tolerance) {
                save(first)
            } else {
                pendingFirstDraw = nil
                phase = .enrollFirst
                isError = true
                message = "Los dos trazos no se parecen. Empezamos otra vez."
            }

        case .locked:
            guard let secret = LockStore.load() else {
                phase = .enrollFirst
                return
            }
            if StrokeMatcher.matches(drawn, template: secret.pattern, tolerance: secret.tolerance) {
                unlock()
            } else {
                fail("Ese no es el trazo.")
            }

        case .unlocked:
            break
        }
    }

    // MARK: - Face ID

    /// Dónde se guarda si quieres Face ID. En UserDefaults y no en el Keychain
    /// porque es una preferencia, no un secreto: apagarla no abre nada.
    public static let biometricsPreferenceKey = "tc.useBiometrics"

    public static var biometricsEnabled: Bool {
        UserDefaults.standard.object(forKey: biometricsPreferenceKey) as? Bool ?? true
    }

    func tryBiometrics() async {
        guard Self.biometricsEnabled else { return }
        guard phase == .locked, !isWaitingOutPenalty else { return }
        // La clase es @MainActor, así que al volver del await seguimos en el hilo bueno.
        if await BiometricAuth.authenticate() { unlock() }
    }

    // MARK: - Ajustes

    /// Vuelve a pedir el trazo. Se llama al salir de la app.
    public func relock() {
        guard LockStore.hasPattern else { return }
        phase = .locked
        message = nil
        isError = false
        pendingFirstDraw = nil
    }

    /// Borra el trazo guardado y arranca una grabación nueva.
    public func resetPattern() {
        LockStore.delete()
        pendingFirstDraw = nil
        failedAttempts = 0
        lockedUntil = nil
        phase = .enrollFirst
        message = nil
        isError = false
    }

    // MARK: - Privado

    private func save(_ pattern: StrokePattern) {
        do {
            try LockStore.save(LockSecret(pattern: pattern, tolerance: tolerance))
            pendingFirstDraw = nil
            unlock()
        } catch {
            pendingFirstDraw = nil
            phase = .enrollFirst
            isError = true
            message = "No se ha podido guardar el trazo en el iPhone."
        }
    }

    private func unlock() {
        failedAttempts = 0
        lockedUntil = nil
        message = nil
        isError = false
        phase = .unlocked
    }

    private func fail(_ text: String) {
        isError = true
        failedAttempts += 1

        if failedAttempts >= maxAttempts {
            lockedUntil = Date().addingTimeInterval(penalty)
            failedAttempts = 0
            message = "Tres fallos. Espera medio minuto."
        } else {
            let left = maxAttempts - failedAttempts
            message = "\(text) Te quedan \(left) \(left == 1 ? "intento" : "intentos")."
        }
    }
}
