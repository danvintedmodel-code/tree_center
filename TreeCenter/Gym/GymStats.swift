import Foundation
import TreeCenterCore
import TreeCenterData

// Las cuentas del gimnasio que salen del historial: kilos movidos por semana,
// el máximo de cada ejercicio por semana y las repeticiones de la última vez.
//
// Siempre sobre series hechas (`done`): una serie apuntada y no marcada es un
// plan, no algo que levantaste.

enum GymStats {

    /// Las semanas empiezan en lunes.
    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    /// El inicio de cada una de las últimas `count` semanas, de la más antigua
    /// a la actual.
    private static func weekStarts(_ count: Int, now: Date) -> [Date] {
        let cal = calendar
        guard let current = cal.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<count).compactMap { k in
            cal.date(byAdding: .weekOfYear, value: -(count - 1 - k), to: current.start)
        }
    }

    private static func weekIndex(of date: Date, starts: [Date]) -> Int? {
        guard let first = starts.first, date >= first else { return nil }
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: starts.last ?? first) ?? first
        guard date < end else { return nil }
        return starts.lastIndex { $0 <= date }
    }

    /// Kilos movidos (peso × repeticiones) en cada una de las últimas semanas.
    static func weeklyVolume(_ workouts: [Workout], weeks: Int = 4, now: Date = .now) -> [Double] {
        let starts = weekStarts(weeks, now: now)
        var result = Array(repeating: 0.0, count: starts.count)
        for workout in workouts {
            guard let index = weekIndex(of: workout.date, starts: starts) else { continue }
            result[index] += workout.volume
        }
        return result
    }

    /// El peso máximo de un ejercicio en cada semana, saltándose las semanas en
    /// que no se hizo: una semana sin entrenar no es una semana estancada.
    static func weeklyTops(of exercise: Exercise, weeks: Int = 4, now: Date = .now) -> [Double] {
        let starts = weekStarts(weeks, now: now)
        var tops = Array(repeating: Double?.none, count: starts.count)

        for entry in exercise.sets where entry.done {
            guard let weight = entry.weight,
                  let date = entry.doneAt ?? entry.workout?.date,
                  let index = weekIndex(of: date, starts: starts) else { continue }
            tops[index] = max(tops[index] ?? 0, weight)
        }
        return tops.compactMap { $0 }
    }

    /// Las repeticiones de cada serie hecha en la última sesión terminada con
    /// ese ejercicio, sin contar la de hoy si sigue abierta.
    static func lastReps(of exercise: Exercise, excluding current: Workout?) -> [Int] {
        let done = exercise.sets.filter { entry in
            guard entry.done, let workout = entry.workout else { return false }
            if let current, workout.persistentModelID == current.persistentModelID { return false }
            return true
        }
        guard let latest = done.compactMap(\.workout).max(by: { $0.date < $1.date }) else { return [] }
        return done
            .filter { $0.workout?.persistentModelID == latest.persistentModelID }
            .sorted { $0.index < $1.index }
            .map(\.reps)
    }

    static func kilos(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + " kg"
    }

    /// Qué toca la próxima vez, en una frase.
    static func adviceText(for planned: PlannedExercise, lastReps: [Int]) -> (advice: ProgressionAdvice, text: String) {
        let weight = planned.weight ?? 0
        let name = planned.exercise?.name ?? ""
        let advice = Progression.advice(lastReps: lastReps, sets: planned.sets,
                                        low: planned.repsLow, high: planned.reps,
                                        weight: weight, step: Progression.step(forExerciseNamed: name))
        switch advice {
        case .increaseWeight(let next):
            return (advice, "Cerraste las \(planned.sets) series a \(planned.reps) reps. Toca subir a \(kilos(next)).")
        case .addRep:
            return (advice, "Mismo peso, y busca una rep más en la serie más floja. Cuando todas lleguen a \(planned.reps), sube.")
        case .hold:
            return (advice, "Alguna serie se quedó por debajo de \(planned.repsLow). Mantén \(kilos(weight)) hasta cerrarlas todas.")
        case .noData:
            return (advice, "Haz una sesión y aquí verás qué toca la siguiente.")
        }
    }
}
