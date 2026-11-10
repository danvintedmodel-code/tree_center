import Foundation

// Las estadísticas de un proyecto o un curso: cuántas cosas se hicieron cada
// día, cada semana y cada mes, y la racha.
//
// Recibe fechas sueltas (una tarea cerrada, una nota, una lección) y las cuenta
// en cubos que terminan hoy. El calendario se pasa de fuera para que las pruebas
// no dependan del huso horario de la máquina que las corre.

public enum ActivityPeriod: String, CaseIterable, Sendable {
    case day, week, month
}

public enum ActivityStats {

    /// `count` cubos que terminan en el periodo actual, del más antiguo al de
    /// hoy. Las semanas empiezan en lunes, como en España.
    public static func buckets(_ dates: [Date], period: ActivityPeriod, count: Int,
                               now: Date, calendar: Calendar) -> [Int] {
        guard count > 0 else { return [] }

        var cal = calendar
        cal.firstWeekday = 2

        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }

        guard let current = cal.dateInterval(of: component, for: now) else {
            return Array(repeating: 0, count: count)
        }

        // El inicio de cada cubo, del más antiguo al actual.
        let starts: [Date] = (0..<count).compactMap { k in
            cal.date(byAdding: component, value: -(count - 1 - k), to: current.start)
        }
        guard starts.count == count else { return Array(repeating: 0, count: count) }

        var result = Array(repeating: 0, count: count)
        for date in dates {
            guard date >= starts[0], date < current.end else { continue }
            // El último cubo cuyo inicio no sea posterior a la fecha.
            if let index = starts.lastIndex(where: { $0 <= date }) {
                result[index] += 1
            }
        }
        return result
    }

    /// Días seguidos con algo hecho, contando hacia atrás desde hoy. Si hoy
    /// todavía no has hecho nada, la racha no se rompe: cuenta desde ayer.
    public static func streak(_ dates: [Date], now: Date, calendar: Calendar) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)

        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Lo hecho en la semana en curso.
    public static func thisWeek(_ dates: [Date], now: Date, calendar: Calendar) -> Int {
        buckets(dates, period: .week, count: 1, now: now, calendar: calendar).first ?? 0
    }
}
