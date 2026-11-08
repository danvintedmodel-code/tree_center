import Foundation
import SwiftData

// Finanzas.
//
// Una cartera y una sección son el mismo modelo con un padre opcional: una
// subcartera es una cartera con padre. Eso permite anidar sin escribir nada nuevo.
//
// El saldo es acumulado y no se reinicia nunca; entra, sale y el tope son del mes
// en curso. Esa diferencia es lo que hace que el saldo sea un saldo.
//
// Un traspaso es UN registro con origen y destino, no dos movimientos sueltos:
// así borrar uno no descuadra nada, y no infla el gasto del mes con dinero que
// no has gastado.

@Model
public final class Wallet {
    public var name: String = ""
    public var kindRaw: String = WalletKind.wallet.rawValue
    public var colorRaw: String = PaletteColor.moss.rawValue
    /// Tope de gasto del mes. Solo tiene sentido en carteras y subcarteras.
    public var monthlyCap: Decimal?
    public var order: Int = 0
    public var showsAsRing: Bool = true
    public var createdAt: Date = Date()

    public var parent: Wallet?

    @Relationship(deleteRule: .cascade, inverse: \Wallet.parent)
    public var sections: [Wallet] = []

    // Movement apunta a Wallet por tres sitios distintos, asi que las tres
    // inversas van declaradas a mano. Dejar que SwiftData las adivine con tres
    // candidatas es pedir que empareje la equivocada.

    @Relationship(deleteRule: .nullify, inverse: \Movement.wallet)
    public var movements: [Movement] = []

    @Relationship(deleteRule: .nullify, inverse: \Movement.destination)
    public var incomingTransfers: [Movement] = []

    @Relationship(deleteRule: .nullify, inverse: \Movement.section)
    public var taggedMovements: [Movement] = []

    public init(name: String = "", kind: WalletKind = .wallet,
                color: PaletteColor = .moss, monthlyCap: Decimal? = nil, order: Int = 0) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.colorRaw = color.rawValue
        self.monthlyCap = monthlyCap
        self.order = order
        self.createdAt = Date()
    }

    public var kind: WalletKind { WalletKind(rawValue: kindRaw) ?? .wallet }
    public var color: PaletteColor { PaletteColor(rawValue: colorRaw) ?? .moss }

    /// Una etiqueta no lleva tope ni sale como aro, diga lo que diga lo guardado.
    public var effectiveCap: Decimal? { kind.canHaveCap ? monthlyCap : nil }
    public var canBeARing: Bool { kind.canBeARing }

    public var orderedSections: [Wallet] { sections.sorted { $0.order < $1.order } }

    // MARK: - Cuentas

    /// Acumulado desde siempre: ingresos menos gastos, más lo que entra y sale
    /// por traspasos.
    public var balance: Decimal {
        var total: Decimal = 0
        for movement in movements {
            switch movement.kind {
            case .income: total += movement.amount
            case .expense: total -= movement.amount
            case .transfer: total -= movement.amount
            }
        }
        for movement in incomingTransfers where movement.kind == .transfer {
            total += movement.amount
        }
        return total
    }

    public func spent(in month: DateInterval) -> Decimal {
        movements
            .filter { $0.kind == .expense && month.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    public func earned(in month: DateInterval) -> Decimal {
        movements
            .filter { $0.kind == .income && month.contains($0.date) }
            .reduce(0) { $0 + $1.amount }
    }
}

@Model
public final class Movement {
    public var amount: Decimal = 0
    public var kindRaw: String = MovementKind.expense.rawValue
    public var date: Date = Date()
    public var concept: String = ""
    public var createdAt: Date = Date()

    @Attribute(.externalStorage) public var receipt: Data?

    /// En gasto y traspaso, de dónde sale. En ingreso, dónde entra.
    public var wallet: Wallet?
    /// La sección dentro de esa cartera, si la tiene.
    public var section: Wallet?
    /// Solo en traspaso: a dónde va.
    public var destination: Wallet?

    public init(amount: Decimal = 0, kind: MovementKind = .expense,
                date: Date = Date(), concept: String = "",
                wallet: Wallet? = nil, section: Wallet? = nil, destination: Wallet? = nil) {
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.date = date
        self.concept = concept
        self.wallet = wallet
        self.section = section
        self.destination = destination
        self.createdAt = Date()
    }

    public var kind: MovementKind { MovementKind(rawValue: kindRaw) ?? .expense }

    /// Con signo, para mostrar. Un traspaso no suma ni resta al total.
    public var signedAmount: Decimal { amount * kind.sign }

    public var isValid: Bool {
        guard amount > 0 else { return false }
        if kind == .transfer { return destination != nil && destination !== wallet }
        return wallet != nil
    }
}

@Model
public final class FinanceSettings {
    public var metricRaw: String = WalletMetric.monthSpend.rawValue
    /// 0 fino, 1 medio, 2 grueso.
    public var ringThickness: Int = 1

    public init(metric: WalletMetric = .monthSpend, ringThickness: Int = 1) {
        self.metricRaw = metric.rawValue
        self.ringThickness = ringThickness
    }

    public var metric: WalletMetric { WalletMetric(rawValue: metricRaw) ?? .monthSpend }
}
