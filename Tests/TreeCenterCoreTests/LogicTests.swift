import Foundation
import XCTest
@testable import TreeCenterCore

// La lógica pura de las pantallas nuevas. Todo lo que pueda equivocarse en una
// cuenta se prueba aquí, sin pantallas por medio.

final class ProgressionTests: XCTestCase {

    func testTodasArribaSubeElPeso() {
        let advice = Progression.advice(lastReps: [8, 8, 8, 8], sets: 4, low: 6, high: 8, weight: 82.5, step: 2.5)
        XCTAssertEqual(advice, .increaseWeight(to: 85))
    }

    func testDentroDelRangoBuscaUnaRepMas() {
        let advice = Progression.advice(lastReps: [8, 8, 7, 6], sets: 4, low: 6, high: 8, weight: 82.5, step: 2.5)
        XCTAssertEqual(advice, .addRep)
    }

    func testUnaSeriePorDebajoDelSueloMantiene() {
        let advice = Progression.advice(lastReps: [8, 7, 5], sets: 3, low: 6, high: 8, weight: 45, step: 2.5)
        XCTAssertEqual(advice, .hold)
    }

    /// Haber hecho menos series de las que pide el plan no cuenta como cerrar
    /// el rango, aunque las que hiciste llegaran arriba.
    func testConSeriesDeMenosNoSube() {
        let advice = Progression.advice(lastReps: [8, 8], sets: 4, low: 6, high: 8, weight: 82.5, step: 2.5)
        XCTAssertEqual(advice, .addRep)
    }

    func testSinSesionAnteriorNoHayConsejo() {
        XCTAssertEqual(Progression.advice(lastReps: [], sets: 3, low: 8, high: 10, weight: 20, step: 2.5), .noData)
    }

    func testLasPiernasSubenDeCincoEnCinco() {
        XCTAssertEqual(Progression.step(forExerciseNamed: "Sentadilla"), 5)
        XCTAssertEqual(Progression.step(forExerciseNamed: "Peso muerto rumano"), 5)
        XCTAssertEqual(Progression.step(forExerciseNamed: "Press banca"), 2.5)
    }

    func testTendencia() {
        XCTAssertEqual(Trend.of(weeklyTops: [80, 80, 82.5]), .up)
        XCTAssertEqual(Trend.of(weeklyTops: [70, 70, 67.5]), .down)
        XCTAssertEqual(Trend.of(weeklyTops: [45, 45, 45]), .flat)
        XCTAssertEqual(Trend.of(weeklyTops: [45]), .flat)
        XCTAssertEqual(Trend.flatWeeks(weeklyTops: [40, 45, 45, 45]), 3)
        XCTAssertEqual(Trend.flatWeeks(weeklyTops: []), 0)
    }
}

final class ActivityStatsTests: XCTestCase {

    /// Calendario fijo: gregoriano, en Madrid. Las pruebas no pueden depender
    /// del huso de la máquina donde corren.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testCubosPorDiaTerminanHoy() {
        let now = date(2026, 11, 10)
        let dates = [date(2026, 11, 10), date(2026, 11, 10, 9), date(2026, 11, 8), date(2026, 10, 1)]
        let days = ActivityStats.buckets(dates, period: .day, count: 3, now: now, calendar: calendar)
        // 8, 9 y 10 de noviembre. Lo de octubre queda fuera.
        XCTAssertEqual(days, [1, 0, 2])
    }

    /// La semana empieza en lunes. El 10 de noviembre de 2026 es martes, así que
    /// el domingo 8 cae en la semana anterior.
    func testLasSemanasEmpiezanEnLunes() {
        let now = date(2026, 11, 10)
        let dates = [date(2026, 11, 9), date(2026, 11, 10), date(2026, 11, 8)]
        let weeks = ActivityStats.buckets(dates, period: .week, count: 2, now: now, calendar: calendar)
        XCTAssertEqual(weeks, [1, 2])
        XCTAssertEqual(ActivityStats.thisWeek(dates, now: now, calendar: calendar), 2)
    }

    func testCubosPorMes() {
        let now = date(2026, 11, 10)
        let dates = [date(2026, 9, 30), date(2026, 10, 15), date(2026, 11, 1), date(2026, 11, 2)]
        XCTAssertEqual(ActivityStats.buckets(dates, period: .month, count: 3, now: now, calendar: calendar), [1, 1, 2])
    }

    func testLaRachaNoSeRompePorqueHoyNoHayasHechoNadaTodavia() {
        let now = date(2026, 11, 10, 8)
        let dates = [date(2026, 11, 9), date(2026, 11, 8), date(2026, 11, 7), date(2026, 11, 5)]
        XCTAssertEqual(ActivityStats.streak(dates, now: now, calendar: calendar), 3)
    }

    func testLaRachaSeRompeConUnDiaVacio() {
        let now = date(2026, 11, 10)
        let dates = [date(2026, 11, 10), date(2026, 11, 8)]
        XCTAssertEqual(ActivityStats.streak(dates, now: now, calendar: calendar), 1)
        XCTAssertEqual(ActivityStats.streak([], now: now, calendar: calendar), 0)
    }
}

final class NoteMarkupTests: XCTestCase {

    func testLasCuatroMarcas() {
        let lines = NoteMarkup.parse("# Plan\n[x] Revisar el CI\n[ ] Instalar\n• Probar\n- Otra\nTexto suelto\n")
        XCTAssertEqual(lines, [
            .heading("Plan"),
            .check(done: true, text: "Revisar el CI"),
            .check(done: false, text: "Instalar"),
            .bullet("Probar"),
            .bullet("Otra"),
            .text("Texto suelto"),
            .blank
        ])
    }

    func testMarcarYDesmarcarUnaCasilla() {
        let text = "# Plan\n[ ] Instalar"
        let marked = NoteMarkup.toggleCheck(in: text, line: 1)
        XCTAssertEqual(marked, "# Plan\n[x] Instalar")
        XCTAssertEqual(NoteMarkup.toggleCheck(in: marked, line: 1), text)
        // Una línea que no es casilla no se toca.
        XCTAssertEqual(NoteMarkup.toggleCheck(in: text, line: 0), text)
        XCTAssertEqual(NoteMarkup.toggleCheck(in: text, line: 9), text)
    }

    func testLaMarcaVaAlPrincipioDeLaLineaDelCursor() {
        let result = NoteMarkup.insertMark("[ ] ", in: "uno\ndos", at: 6)
        XCTAssertEqual(result.text, "uno\n[ ] dos")
        XCTAssertEqual(result.cursor, 10)

        let atStart = NoteMarkup.insertMark("# ", in: "", at: 0)
        XCTAssertEqual(atStart.text, "# ")
        XCTAssertEqual(atStart.cursor, 2)
    }

    func testCuentaLasCasillas() {
        let count = NoteMarkup.checkCount("[x] a\n[ ] b\n[x] c\n• d")
        XCTAssertEqual(count.done, 2)
        XCTAssertEqual(count.total, 3)
    }
}

final class IncomeSplitTests: XCTestCase {

    func testLaSumaEsSiempreElIngresoExacto() {
        let parts = IncomeSplit.split(100_001, percents: [50, 30, 10], into: 0)
        XCTAssertEqual(parts.reduce(0, +), 100_001)
        // 30 % y 10 % redondeados hacia abajo; el resto, a la cartera elegida.
        XCTAssertEqual(parts[1], 30_000)
        XCTAssertEqual(parts[2], 10_000)
        XCTAssertEqual(parts[0], 60_001)
    }

    func testSinPorcentajesTodoVaALaCarteraElegida() {
        XCTAssertEqual(IncomeSplit.split(5_000, percents: [0, 0, 0], into: 2), [0, 0, 5_000])
    }

    func testUnPorcentajeNoPuedePasarDeLoQueQueda() {
        XCTAssertEqual(IncomeSplit.maxPercent(for: 2, in: [50, 30, 10]), 20)
        XCTAssertEqual(IncomeSplit.unassigned([50, 30, 10]), 10)
        XCTAssertEqual(IncomeSplit.unassigned([60, 50]), 0)
    }

    func testIndiceFueraDeRangoNoRompe() {
        XCTAssertEqual(IncomeSplit.split(1_000, percents: [50, 50], into: 7), [0, 0])
    }
}
