import Foundation
import SwiftData
import XCTest
@testable import TreeCenterData

// Un esquema de SwiftData puede compilar perfectamente y reventar al arrancar:
// una inversa mal emparejada no es un error de tipos, es un error de ejecución.
// Por eso estas pruebas levantan un almacén de verdad en lugar de mirar el código.

final class SchemaTests: XCTestCase {

    @MainActor
    private func freshContext() throws -> ModelContext {
        let container = try TreeCenterSchema.container(inMemory: true)
        return container.mainContext
    }

    // MARK: - Que el esquema exista

    @MainActor
    func testElEsquemaArranca() throws {
        XCTAssertNoThrow(try TreeCenterSchema.container(inMemory: true),
                         "Si esto falla, hay una relación mal declarada")
    }

    @MainActor
    func testElPrimerArranqueDejaLaCasaMontada() throws {
        let context = try freshContext()
        try TreeCenterSchema.seedIfEmpty(context)

        let routines = try context.fetch(FetchDescriptor<Routine>())
        XCTAssertEqual(routines.count, 1)
        XCTAssertEqual(routines.first?.days.count, 7, "La semana tiene siete días, siempre")
        XCTAssertEqual(routines.first?.restDays.count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Wallet>()).count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HomeWidget>()).count, 3)
    }

    @MainActor
    func testElArranqueNoDuplicaSiYaHayDatos() throws {
        let context = try freshContext()
        try TreeCenterSchema.seedIfEmpty(context)
        try TreeCenterSchema.seedIfEmpty(context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Routine>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Wallet>()).count, 3)
    }

    // MARK: - La regla de los días

    @MainActor
    func testSoloSePuedeQuitarElFinDeSemana() throws {
        let context = try freshContext()
        try TreeCenterSchema.seedIfEmpty(context)
        let routine = try XCTUnwrap(try context.fetch(FetchDescriptor<Routine>()).first)

        let wednesday = try XCTUnwrap(routine.day(.wednesday))
        XCTAssertFalse(wednesday.makeRestDay(), "De lunes a viernes no se tocan")
        XCTAssertFalse(wednesday.isRestDay)

        let saturday = try XCTUnwrap(routine.day(.saturday))
        XCTAssertTrue(saturday.isRestDay)
        XCTAssertTrue(routine.isValid)
    }

    @MainActor
    func testLaSemanaEmpiezaEnLunes() {
        // Calendar: 1 = domingo, 2 = lunes … 7 = sábado.
        XCTAssertEqual(Weekday.from(calendarWeekday: 2), .monday)
        XCTAssertEqual(Weekday.from(calendarWeekday: 7), .saturday)
        XCTAssertEqual(Weekday.from(calendarWeekday: 1), .sunday)
        XCTAssertTrue(Weekday.from(calendarWeekday: 1).canBeRestDay)
        XCTAssertFalse(Weekday.from(calendarWeekday: 2).canBeRestDay)
    }

    // MARK: - Finanzas

    @MainActor
    func testElTraspasoMueveSaldoPeroNoCuentaComoGasto() throws {
        let context = try freshContext()

        let daily = Wallet(name: "Diario", monthlyCap: 500)
        let savings = Wallet(name: "Ahorro", color: .blue)
        context.insert(daily)
        context.insert(savings)

        context.insert(Movement(amount: 1800, kind: .income, concept: "Nómina", wallet: daily))
        context.insert(Movement(amount: 12.40, kind: .expense, concept: "Metro", wallet: daily))
        context.insert(Movement(amount: 300, kind: .transfer, concept: "A Ahorro",
                                wallet: daily, destination: savings))
        try context.save()

        let month = Calendar.current.monthInterval()

        XCTAssertEqual(daily.balance, Decimal(string: "1487.60"))
        XCTAssertEqual(savings.balance, 300)

        XCTAssertEqual(daily.spent(in: month), Decimal(string: "12.40"),
                       "Un traspaso no es dinero gastado: solo cambia de sitio")
        XCTAssertEqual(daily.earned(in: month), 1800)
    }

    @MainActor
    func testUnTraspasoSinDestinoNoEsValido() {
        let orphan = Movement(amount: 50, kind: .transfer, wallet: Wallet(name: "Diario"))
        XCTAssertFalse(orphan.isValid)

        let toItself = Wallet(name: "Diario")
        let circular = Movement(amount: 50, kind: .transfer, wallet: toItself, destination: toItself)
        XCTAssertFalse(circular.isValid, "Traspasarse dinero a uno mismo no significa nada")
    }

    @MainActor
    func testUnaEtiquetaNoTieneTopePorMuchoQueSeLeGuarde() {
        let tag = WalletSection(name: "Transporte", kind: .tag, monthlyCap: 100)
        XCTAssertNil(tag.effectiveCap, "Una etiqueta solo agrupa; el tope es de las subcarteras")
        XCTAssertFalse(tag.canBeARing)

        let sub = WalletSection(name: "Comida", kind: .wallet, monthlyCap: 250)
        XCTAssertEqual(sub.effectiveCap, 250)
        XCTAssertTrue(sub.canBeARing)
    }

    @MainActor
    func testLasSeccionesCuelganDeSuCartera() throws {
        let context = try freshContext()

        let daily = Wallet(name: "Diario")
        let food = WalletSection(name: "Comida", kind: .wallet, monthlyCap: 250, order: 0)
        let transport = WalletSection(name: "Transporte", kind: .tag, order: 1)
        context.insert(daily)
        context.insert(food)
        context.insert(transport)
        food.wallet = daily
        transport.wallet = daily
        try context.save()

        XCTAssertEqual(daily.orderedSections.map(\.name), ["Comida", "Transporte"])
        XCTAssertEqual(food.wallet?.name, "Diario")
    }

    @MainActor
    func testCambiarDeEtiquetaASubcarteraNoPierdeGastos() throws {
        let context = try freshContext()

        let daily = Wallet(name: "Diario")
        let transport = WalletSection(name: "Transporte", kind: .tag)
        context.insert(daily)
        context.insert(transport)
        transport.wallet = daily
        context.insert(Movement(amount: 12.40, kind: .expense, concept: "Metro",
                                wallet: daily, section: transport))
        try context.save()

        transport.kindRaw = WalletKind.wallet.rawValue
        transport.monthlyCap = 80
        try context.save()

        XCTAssertEqual(transport.movements.count, 1, "Cambiar de clase no borra lo apuntado")
        XCTAssertEqual(transport.effectiveCap, 80)
    }

    // MARK: - Alimentación

    @MainActor
    func testLoComidoNoCambiaAunqueCambieLaReceta() {
        let recipe = Recipe(name: "Tortilla de avena", kcal: 412, proteinG: 34)
        let eaten = MealEntry(copying: recipe)

        recipe.name = "Tortilla de avena v2"
        recipe.kcal = 500

        XCTAssertEqual(eaten.name, "Tortilla de avena")
        XCTAssertEqual(eaten.kcal, 412, "Lo que comiste el martes no cambia al editar la receta")
    }

    // MARK: - Biblioteca

    @MainActor
    func testElLomoLoDanLasPaginas() {
        let thin = Book(title: "Meditaciones", pages: 180)
        let fat = Book(title: "Dune", pages: 700)
        XCTAssertLessThan(thin.spineWidth, fat.spineWidth)
        XCTAssertGreaterThanOrEqual(thin.spineWidth, 20)
        XCTAssertLessThanOrEqual(fat.spineWidth, 44)
    }
}
