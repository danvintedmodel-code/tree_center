import Foundation

// El reparto de un ingreso entre carteras según sus porcentajes.
//
// En céntimos y con enteros, como todo el dinero de la app: cada cartera recibe
// su parte redondeada hacia abajo, y lo que sobra (la parte sin asignar y los
// céntimos del redondeo) va a la cartera donde se apunta el ingreso. Así la suma
// de las partes es siempre exactamente el ingreso, ni un céntimo más ni menos.

public enum IncomeSplit {

    /// - Parameters:
    ///   - cents: el ingreso.
    ///   - percents: el porcentaje de cada cartera, en su orden.
    ///   - into: la cartera donde se apunta, que recibe el resto.
    /// - Returns: lo que le toca a cada cartera, en el mismo orden.
    public static func split(_ cents: Int, percents: [Int], into: Int) -> [Int] {
        guard cents > 0, percents.indices.contains(into) else {
            return percents.indices.map { $0 == into ? max(cents, 0) : 0 }
        }

        var parts = percents.map { cents * min(max($0, 0), 100) / 100 }
        let given = parts.reduce(0, +)
        parts[into] += cents - given
        return parts
    }

    /// La suma de porcentajes no puede pasar de 100. Devuelve el máximo que
    /// puede tener la cartera `index` sin pasarse.
    public static func maxPercent(for index: Int, in percents: [Int]) -> Int {
        let others = percents.enumerated()
            .filter { $0.offset != index }
            .reduce(0) { $0 + max($1.element, 0) }
        return max(0, 100 - others)
    }

    public static func unassigned(_ percents: [Int]) -> Int {
        max(0, 100 - percents.reduce(0) { $0 + max($1, 0) })
    }
}
