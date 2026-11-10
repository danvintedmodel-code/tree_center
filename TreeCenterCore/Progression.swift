import Foundation

// Qué toca la próxima vez en un ejercicio.
//
// La regla es la doble progresión, la más usada y la que menos lesiona porque
// nunca sube dos cosas a la vez: con un rango de repeticiones (por ejemplo 6–8),
// primero se suben repeticiones dentro del rango y solo cuando todas las series
// llegan arriba se sube el peso, volviendo al suelo del rango.

public enum ProgressionAdvice: Equatable, Sendable {
    /// Todas las series llegaron al techo: sube el peso.
    case increaseWeight(to: Double)
    /// Dentro del rango: mismo peso, una repetición más en la serie más floja.
    case addRep
    /// Alguna serie no llegó ni al suelo: mantén el peso hasta cerrarlas.
    case hold
    /// Sin sesión anterior no hay con qué comparar.
    case noData
}

public enum Progression {

    /// - Parameters:
    ///   - lastReps: las repeticiones de cada serie de la última sesión.
    ///   - sets: las series que pide el plan. Si hiciste menos, no se sube.
    ///   - low, high: el rango de repeticiones.
    ///   - weight: el peso de trabajo actual.
    ///   - step: cuánto se sube de golpe.
    public static func advice(lastReps: [Int], sets: Int, low: Int, high: Int,
                              weight: Double, step: Double) -> ProgressionAdvice {
        guard !lastReps.isEmpty else { return .noData }

        if lastReps.contains(where: { $0 < low }) { return .hold }

        // Subir pide haber hecho todas las series del plan, todas arriba. Una
        // serie que falta no cuenta como hecha.
        if lastReps.count >= sets && lastReps.allSatisfy({ $0 >= high }) {
            return .increaseWeight(to: weight + step)
        }
        return .addRep
    }

    /// Las piernas aguantan saltos más grandes que los brazos.
    public static func step(forExerciseNamed name: String) -> Double {
        let lower = ["sentadilla", "peso muerto", "prensa", "gemelo", "zancada", "hip thrust"]
        let lowered = name.lowercased()
        return lower.contains(where: { lowered.contains($0) }) ? 5 : 2.5
    }
}

/// Cómo va un ejercicio en las últimas semanas, mirando el peso máximo de cada
/// una.
public enum Trend: Equatable, Sendable {
    case up, flat, down

    /// Con menos de dos semanas no hay tendencia que valga: se da por plano.
    public static func of(weeklyTops tops: [Double]) -> Trend {
        guard let first = tops.first, let last = tops.last, tops.count >= 2 else { return .flat }
        if last > first { return .up }
        if last < first { return .down }
        return .flat
    }

    /// Cuántas semanas seguidas, contando desde la última, lleva el mismo
    /// máximo. Es el «3 semanas sin moverse» que avisa de un estancamiento.
    public static func flatWeeks(weeklyTops tops: [Double]) -> Int {
        guard let last = tops.last else { return 0 }
        var count = 0
        for value in tops.reversed() {
            guard value == last else { break }
            count += 1
        }
        return count
    }
}
