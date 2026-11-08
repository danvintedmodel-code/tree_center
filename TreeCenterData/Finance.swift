import Foundation
import SwiftData

// Finanzas.
//
// Una cartera tiene secciones, y una sección es etiqueta o subcartera. Antes esto
// era un solo modelo apuntándose a sí mismo, que permitía anidar sin límite y
// hacía caer a SwiftData; el diseño nunca pidió más de un nivel, así que son dos
// tipos y se acabó el problema.
//
// Los importes van en céntimos enteros: ver Money.swift.
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
    public var colorRaw: String = PaletteColor.moss.rawValue
    /// Tope de gasto del mes, en céntimos. Nil = sin tope.
    public var monthlyCapCents: Int?
    public var order: Int = 0
    public var showsAsRing: Bool = true
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WalletSection.wallet)
    public var sections: [WalletSection] = []

    // Movement apunta a Wallet por dos sitios, así que las dos inversas van
    // declaradas a mano: con dos candidatas, dejar que SwiftData adivine es
    // pedir que empareje la equivocada.

    @Relationship(deleteRule: .nullify, inverse: \Movement.wallet)
    public var movements: [Movement] = []

    @Relationship(deleteRule: .nullify, inverse: \Movement.destination)
    public var incomingTransfers: [Movement] = []

    public init(name: String = "", color: PaletteColor = .moss,
                monthlyCapCents: Int? = nil, order: Int = 0) {
        self.name = name
        self.colorRaw = color.rawValue
        self.monthlyCapCents = monthlyCapCents
        self.order = order
        self.createdAt = Date()
    }

    public var color: PaletteColor { PaletteColor(rawValue: colorRaw) ?? .moss }
    public var monthlyCap: Decimal? { monthlyCapCents.map(Cents.decimal) }
    public var orderedSections: [WalletSection] { sections.sorted { $0.order < $1.order } }

    // MARK: - Cuentas

    /// Acumulado desde siempre: ingresos menos gastos, más lo que entra y sale
    /// por traspasos. No se reinicia al cambiar de mes.
    public var balanceCents: Int {
        var total = 0
        for movement in movements {
            switch movement.kind {
            case .income: total += movement.amountCents
            case .expense, .transfer: total -= movement.amountCents
            }
        }
        for movement in incomingTransfers where movement.kind == .transfer {
            total += movement.amountCents
        }
        return total
    }

    public var balance: Decimal { Cents.decimal(balanceCents) }

    public func spentCents(in month: DateInterval) -> Int {
        movements
            .filter { $0.kind == .expense && month.contains($0.date) }
            .reduce(0) { $0 + $1.amountCents }
    }

    public func earnedCents(in month: DateInterval) -> Int {
        movements
            .filter { $0.kind == .income && month.contains($0.date) }
            .reduce(0) { $0 + $1.amountCents }
    }
}

/// Una división dentro de una cartera. Etiqueta agrupa y ya; subcartera lleva
/// tope propio y puede salir como aro. Se cambia de una a otra sin perder gastos.
@Model
public final class WalletSection {
    public var name: String = ""
    public var kindRaw: String = WalletKind.tag.rawValue
    public var monthlyCapCents: Int?
    public var order: Int = 0

    public var wallet: Wallet?

    @Relationship(deleteRule: .nullify, inverse: \Movement.section)
    public var movements: [Movement] = []

    public init(name: String = "", kind: WalletKind = .tag,
                monthlyCapCents: Int? = nil, order: Int = 0) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.monthlyCapCents = monthlyCapCents
        self.order = order
    }

    public var kind: WalletKind { WalletKind(rawValue: kindRaw) ?? .tag }

    /// Una etiqueta no tiene tope por mucho que haya un número guardado.
    public var effectiveCapCents: Int? { kind.canHaveCap ? monthlyCapCents : nil }
    public var effectiveCap: Decimal? { effectiveCapCents.map(Cents.decimal) }
    public var canBeARing: Bool { kind.canBeARing }

    public func spentCents(in month: DateInterval) -> Int {
        movements
            .filter { $0.kind == .expense && month.contains($0.date) }
            .reduce(0) { $0 + $1.amountCents }
    }
}

@Model
public final class Movement {
    public var amountCents: Int = 0
    public var kindRaw: String = MovementKind.expense.rawValue
    public var date: Date = Date()
    public var concept: String = ""
    public var createdAt: Date = Date()

    @Attribute(.externalStorage) public var receipt: Data?

    /// En gasto y traspaso, de dónde sale. En ingreso, dónde entra.
    public var wallet: Wallet?
    /// La sección dentro de esa cartera, si la tiene.
    public var section: WalletSection?
    /// Solo en traspaso: a dónde va.
    public var destination: Wallet?

    public init(amountCents: Int = 0, kind: MovementKind = .expense,
                date: Date = Date(), concept: String = "",
                wallet: Wallet? = nil, section: WalletSection? = nil,
                destination: Wallet? = nil) {
        self.amountCents = amountCents
        self.kindRaw = kind.rawValue
        self.date = date
        self.concept = concept
        self.wallet = wallet
        self.section = section
        self.destination = destination
        self.createdAt = Date()
    }

    public var kind: MovementKind { MovementKind(rawValue: kindRaw) ?? .expense }
    public var amount: Decimal { Cents.decimal(amountCents) }

    /// Con signo, para mostrar. Un traspaso no suma ni resta al total.
    public var signedCents: Int {
        switch kind {
        case .expense: return -amountCents
        case .income: return amountCents
        case .transfer: return 0
        }
    }

    public var isValid: Bool {
        guard amountCents > 0 else { return false }
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
