import Foundation
import SwiftData
import XCTest
@testable import TreeCenterData

// Un grupo de modelos, un almacén, un guardado.
//
// Cuando el esquema completo revienta en el primer `save()` y el error no dice
// nada —el runner se cae y ya— abrirlo por trozos es la forma rápida de saber
// qué trozo lo rompe. Cada prueba de aquí es independiente: si solo cae una, esa
// es la culpable; si caen todas, el problema es común a todos los modelos.
//
// Estas pruebas se quedan aunque el esquema esté sano: son baratas y la próxima
// vez que algo se rompa, el CI señalará el grupo en la primera vuelta.

final class GroupSchemaTests: XCTestCase {

    private var storeURLs: [URL] = []

    override func tearDown() {
        for url in storeURLs { try? FileManager.default.removeItem(at: url) }
        storeURLs = []
        super.tearDown()
    }

    @MainActor
    private func context(_ models: [any PersistentModel.Type],
                         _ label: String) throws -> ModelContext {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tc-\(label)-\(UUID().uuidString).store")
        storeURLs.append(url)
        print("[grupo] \(label): abriendo")
        let context = try TreeCenterSchema.container(models: models, at: url).mainContext
        print("[grupo] \(label): abierto")
        return context
    }

    @MainActor
    func testGrupoGimnasio() throws {
        let context = try context(TreeCenterSchema.fitnessModels, "gimnasio")
        context.insert(Exercise(name: "Press banca"))
        context.insert(Workout(templateName: "Empuje"))
        context.insert(BodyMeasurement(weightKg: 78.4))
        print("[grupo] gimnasio: guardando")
        XCTAssertNoThrow(try context.save())
        print("[grupo] gimnasio: ok")
    }

    @MainActor
    func testGrupoAlimentacion() throws {
        let context = try context(TreeCenterSchema.foodModels, "alimentacion")
        context.insert(RecipeBook(name: "Recetas"))
        context.insert(Recipe(name: "Tortilla de avena", kcal: 412))
        context.insert(MealEntry(name: "Café", kcal: 5))
        print("[grupo] alimentacion: guardando")
        XCTAssertNoThrow(try context.save())
        print("[grupo] alimentacion: ok")
    }

    @MainActor
    func testGrupoArmario() throws {
        let context = try context(TreeCenterSchema.wardrobeModels, "armario")
        context.insert(Garment(name: "Sudadera verde", category: .hoodies))
        context.insert(Outfit(name: "Diario"))
        print("[grupo] armario: guardando")
        XCTAssertNoThrow(try context.save())
        print("[grupo] armario: ok")
    }

    @MainActor
    func testGrupoFinanzas() throws {
        let context = try context(TreeCenterSchema.financeModels, "finanzas")
        context.insert(Wallet(name: "Diario", monthlyCapCents: 50_000))
        context.insert(Movement(amountCents: 1_240, concept: "Metro"))
        print("[grupo] finanzas: guardando")
        XCTAssertNoThrow(try context.save())
        print("[grupo] finanzas: ok")
    }

    @MainActor
    func testGrupoVida() throws {
        let context = try context(TreeCenterSchema.lifeModels, "vida")
        context.insert(ImportantDate(title: "Renovar dominio"))
        context.insert(Project(name: "Proyecto A"))
        context.insert(Course(name: "Swift desde cero", totalLessons: 29))
        context.insert(Book(title: "Meditaciones", pages: 180))
        context.insert(WishItem(name: "Silla"))
        context.insert(Place(name: "Kioto", country: "Japón"))
        context.insert(HomeWidget())
        print("[grupo] vida: guardando")
        XCTAssertNoThrow(try context.save())
        print("[grupo] vida: ok")
    }

    @MainActor
    func testEsquemaCompleto() throws {
        let context = try context(TreeCenterSchema.models, "completo")
        context.insert(Wallet(name: "Diario"))
        print("[grupo] completo: guardando")
        XCTAssertNoThrow(try context.save())
        print("[grupo] completo: ok")
    }
}
