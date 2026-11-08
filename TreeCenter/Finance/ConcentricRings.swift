import SwiftUI
import TreeCenterData

// Los aros. El de fuera es el Total y cada uno de dentro una cartera.
//
// Pasados cuatro o cinco dejan de leerse por mucho color que tengan, así que
// `maxRings` recorta y el configurador avisa en vez de dejarte llenarlo.

struct ConcentricRings: View {
    struct Ring: Identifiable {
        let id: String
        let value: Double
        let color: Color
    }

    let rings: [Ring]
    var lineWidth: CGFloat = 13
    var spacing: CGFloat = 3

    static let maxRings = 5

    var body: some View {
        ZStack {
            ForEach(Array(rings.prefix(Self.maxRings).enumerated()), id: \.element.id) { index, ring in
                ZStack {
                    Circle().stroke(TCColor.track, lineWidth: lineWidth)
                    Circle()
                        .trim(from: 0, to: min(1, max(0, ring.value)))
                        .stroke(ring.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .padding(CGFloat(index) * (lineWidth + spacing) + lineWidth / 2)
            }
        }
        .animation(.easeOut(duration: 0.3), value: rings.map(\.value))
    }
}

extension PaletteColor {
    /// El color de la paleta, resuelto. Los modelos guardan el nombre; el color
    /// de verdad lo pone el tema, que es lo que permite que funcione en claro y
    /// en oscuro sin tocar un solo dato.
    var swiftUI: Color {
        switch self {
        case .moss: return TCColor.moss
        case .blue: return TCColor.blue
        case .sand: return TCColor.sand
        case .clay: return TCColor.clay
        case .lilac: return TCColor.lilac
        case .neutral: return TCColor.textSoft
        }
    }
}

// MARK: - Qué mide cada aro

/// Las cuentas de la pantalla de Finanzas, fuera de las vistas para poder
/// mirarlas sin abrir un simulador.
enum WalletFigures {

    /// Lo que mide la cartera según el selector, en céntimos.
    static func amount(_ wallet: Wallet, metric: WalletMetric, month: DateInterval) -> Int {
        switch metric {
        case .monthSpend: return wallet.spentCents(in: month)
        case .monthIncome: return wallet.earnedCents(in: month)
        case .balance: return max(0, wallet.balanceCents)
        }
    }

    /// Lo lleno que va su aro. Con tope, es lo gastado contra el tope, que es
    /// la lectura útil. Sin tope, su parte del total, que al menos compara.
    static func fill(_ wallet: Wallet, metric: WalletMetric,
                     month: DateInterval, total: Int) -> Double {
        let value = amount(wallet, metric: metric, month: month)

        if metric == .monthSpend, let cap = wallet.monthlyCapCents, cap > 0 {
            return Double(value) / Double(cap)
        }
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }

    static func total(_ wallets: [Wallet], metric: WalletMetric, month: DateInterval) -> Int {
        wallets.reduce(0) { $0 + amount($1, metric: metric, month: month) }
    }

    /// El tope conjunto, solo si alguna cartera tiene uno puesto.
    static func totalCap(_ wallets: [Wallet]) -> Int? {
        let caps = wallets.compactMap(\.monthlyCapCents)
        return caps.isEmpty ? nil : caps.reduce(0, +)
    }

    static func share(_ wallet: Wallet, metric: WalletMetric,
                      month: DateInterval, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(amount(wallet, metric: metric, month: month)) / Double(total)
    }
}
