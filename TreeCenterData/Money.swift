import Foundation

// El dinero se guarda en céntimos enteros, nunca en Decimal ni en Double.
//
// Dos razones, y las dos buenas. La primera es de siempre: sumar importes en
// coma flotante arrastra errores, y 0,1 + 0,2 no da 0,3. La segunda la descubrió
// el CI a base de palos: SwiftData revienta al guardar un `Decimal?`.
//
// Un Int no se rompe, no redondea mal y compara exacto. Para mostrar se convierte
// al vuelo, que es cuando de verdad hace falta un decimal.

public enum Cents {
    /// De euros a céntimos, redondeando al céntimo más cercano.
    public static func from(_ amount: Decimal) -> Int {
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// De céntimos a euros, para mostrar o para cuadrar cuentas.
    public static func decimal(_ cents: Int) -> Decimal {
        Decimal(cents) / 100
    }

    /// "1 388,00 €", con el formato que tenga puesto el iPhone.
    public static func formatted(_ cents: Int, code: String = "EUR") -> String {
        decimal(cents).formatted(.currency(code: code))
    }
}
