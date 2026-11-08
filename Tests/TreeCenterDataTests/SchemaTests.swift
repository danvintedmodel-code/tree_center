import Foundation
import SwiftData
import XCTest
@testable import TreeCenterData

// Un esquema de SwiftData puede compilar perfectamente y reventar al arrancar o
// al guardar: una inversa mal emparejada o un tipo que no traga no son errores de
// tipos, son errores de ejecución. Por eso estas pruebas levantan un almacén de
// verdad y guardan en él, en vez de limitarse a mirar el código.

final class SchemaTests: XCTestCase {

    private var storeURLs: [URL] = []

    override func tearDown() {
        for url in storeURLs { try? FileManager.default.removeItem(at: url) }
        storeURLs = []
        super.tearDown()
    }

    /// Un almacén nuevo, en disco, por prueba. En disco y no en memoria porque
    /// varios modelos guardan imágenes con `.externalStorage`, y esas necesitan
    /// una carpeta de verdad donde ir a parar.
    @MainActor
    private func freshContext() throws -> ModelContext {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tree-center-\(UUID().uuidString).store")
        storeURLs.append(url)
        return try TreeCenterSchema.container(at: url).mainContext
    }

    // MARK: - Que el esquema exista y aguante un guardado

    @MainActor
    func testElEsquemaArranca() throws {
        XCTAssertNoThrow(try TreeCenterSchema.container(inMemory: true),
                         "Si esto falla, hay una relación mal declarada")
    }

    @MainActor
    func testGuardarUnaCarteraNoRevienta() throws {
        // Esta prueba existe porque un día reventó: un `Decimal?` tumbaba el
        // runner entero al guardar. Ahora el dinero va en céntimos enteros, y
        // esta es la red que avisa si alguien vuelve a meter un decimal.
        let context = try freshContext()
        context.insert(Wallet(name: "Diario", monthlyCapCents: 50_000))
        XCTAssertNoThrow(try context.save())
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

    // MARK: - Dinero

    @MainActor
    func testLosCentimosNoArrastranErrores() {
        XCTAssertEqual(Cents.from(12.40), 1_240)
        XCTAssertEqual(Cents.from(0.1) + Cents.from(0.2), Cents.from(0.3),
                       "Esto es justo lo que falla en coma flotante")
        XCTAssertEqual(Cents.decimal(148_760), Decimal(string: "1487.60"))
        XCTAssertEqual(Cents.from(Cents.decimal(999_999)), 999_999)
    }

    @MainActor
    func testElTraspasoMueveSaldoPeroNoCuentaComoGasto() throws {
        // Las trazas están puestas a propósito: si esto vuelve a caer en el CI,
        // la última línea impresa dice en qué paso se rompió.
        print("[datos] abriendo almacén")
        let context = try freshContext()

        print("[datos] insertando carteras")
        let daily = Wallet(name: "Diario", monthlyCapCents: 50_000)
        let savings = Wallet(name: "Ahorro", color: .blue)
        context.insert(daily)
        context.insert(savings)

        print("[datos] guardando carteras")
        try context.save()

        print("[datos] insertando movimientos")
        context.insert(Movement(amountCents: 180_000, kind: .income,
                                concept: "Nómina", wallet: daily))
        context.insert(Movement(amountCents: 1_240, kind: .expense,
                                concept: "Metro", wallet: daily))
        context.insert(Movement(amountCents: 30_000, kind: .transfer,
                                concept: "A Ahorro", wallet: daily, destination: savings))

        print("[datos] guardando movimientos")
        try context.save()
        print("[datos] guardado")

        let month = Calendar.current.monthInterval()

        XCTAssertEqual(daily.balanceCents, 148_760)
        XCTAssertEqual(savings.balanceCents, 30_000)

        XCTAssertEqual(daily.spentCents(in: month), 1_240,
                       "Un traspaso no es dinero gastado: solo cambia de sitio")
        XCTAssertEqual(daily.earnedCents(in: month), 180_000)
    }

    @MainActor
    func testUnTraspasoSinDestinoNoEsValido() {
        let orphan = Movement(amountCents: 5_000, kind: .transfer, wallet: Wallet(name: "Diario"))
        XCTAssertFalse(orphan.isValid)

        let wallet = Wallet(name: "Diario")
        let circular = Movement(amountCents: 5_000, kind: .transfer,
                                wallet: wallet, destination: wallet)
        XCTAssertFalse(circular.isValid, "Traspasarse dinero a uno mismo no significa nada")
    }

    @MainActor
    func testUnaEtiquetaNoTieneTopePorMuchoQueSeLeGuarde() {
        let tag = WalletSection(name: "Transporte", kind: .tag, monthlyCapCents: 10_000)
        XCTAssertNil(tag.effectiveCapCents, "Una etiqueta solo agrupa; el tope es de las subcarteras")
        XCTAssertFalse(tag.canBeARing)

        let sub = WalletSection(name: "Comida", kind: .wallet, monthlyCapCents: 25_000)
        XCTAssertEqual(sub.effectiveCapCents, 25_000)
        XCTAssertTrue(sub.canBeARing)
    }

    @MainActor
    func testLasSeccionesCuelganDeSuCartera() throws {
        let context = try freshContext()

        let daily = Wallet(name: "Diario")
        let food = WalletSection(name: "Comida", kind: .wallet, monthlyCapCents: 25_000, order: 0)
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
        context.insert(Movement(amountCents: 1_240, kind: .expense, concept: "Metro",
                                wallet: daily, section: transport))
        try context.save()

        transport.kindRaw = WalletKind.wallet.rawValue
        transport.monthlyCapCents = 8_000
        try context.save()

        XCTAssertEqual(transport.movements.count, 1, "Cambiar de clase no borra lo apuntado")
        XCTAssertEqual(transport.effectiveCapCents, 8_000)
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
