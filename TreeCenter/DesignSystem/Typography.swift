import SwiftUI
import UIKit

// Instrument Sans es la única familia de la app.
// Si las fuentes no están instaladas en el bundle todavía, todo cae en San Francisco
// sin romperse: así el proyecto compila y se ve decente desde el primer build.

enum TCFont {
    private static let regular = "InstrumentSans-Regular"
    private static let medium = "InstrumentSans-Medium"
    private static let semibold = "InstrumentSans-SemiBold"
    private static let bold = "InstrumentSans-Bold"

    /// Se calcula una sola vez: comprobar fuentes en cada render es caro.
    private static let isInstalled: Bool = UIFont(name: semibold, size: 12) != nil

    private static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return bold
        case .semibold: return semibold
        case .medium: return medium
        default: return regular
        }
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard isInstalled else { return .system(size: size, weight: weight) }
        return .custom(name(for: weight), size: size)
    }
}

// La escala tipográfica del tablero de sistema, convertida a modificadores.
// El `tracking` va en puntos, no en em: -0.025em sobre 25 pt son -0.63 pt.

extension View {
    /// Título de pantalla. "Tree Center", "Gimnasio", "Finanzas".
    func tcTitle() -> some View {
        font(TCFont.font(25, .semibold)).tracking(-0.63).foregroundStyle(TCColor.text)
    }

    /// Cabecera dentro de una tarjeta. "Empuje · semana 3".
    func tcSection() -> some View {
        font(TCFont.font(18, .semibold)).tracking(-0.36).foregroundStyle(TCColor.text)
    }

    /// Fila de una lista. "Press banca".
    func tcRow() -> some View {
        font(TCFont.font(15, .medium)).foregroundStyle(TCColor.text)
    }

    /// Texto de apoyo bajo una fila.
    func tcBody() -> some View {
        font(TCFont.font(13)).foregroundStyle(TCColor.textSoft)
    }

    /// Pie, unidades, fechas.
    func tcMicro() -> some View {
        font(TCFont.font(11)).foregroundStyle(TCColor.textMicro)
    }

    /// Etiqueta de sección en versales. Se escribe ya en mayúsculas.
    func tcLabel() -> some View {
        font(TCFont.font(10, .semibold)).tracking(1.4).foregroundStyle(TCColor.textMicro)
    }

    /// Cifra grande. Siempre tabular, para que no baile al cambiar.
    func tcNumber(_ size: CGFloat = 22) -> some View {
        font(TCFont.font(size, .semibold))
            .monospacedDigit()
            .tracking(size * -0.03)
            .foregroundStyle(TCColor.text)
    }
}
