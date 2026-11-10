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

    /// Igual que en SchemaTests: el contenedor hay que retenerlo. Un contexto
    /// suelto cuyo contenedor ya se liberó se lleva por delante el proceso.
    private var containers: [ModelContainer] = []

    override func tearDown() {
        containers = []
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
        let container = try TreeCenterSchema.container(models: models, at: url)
        containers.append(container)
        print("[grupo] \(label): abierto")
        return container.mainContext
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

    /// El espacio de trabajo: cada tarea, nota, idea y aviso tiene dos dueños
    /// posibles, un proyecto o un curso. Dos relaciones a-uno opcionales hacia
    /// tipos distintos, cada una con su inversa: justo el tipo de cosa que tumba
    /// SwiftData al guardar si una inversa está mal declarada.
    @MainActor
    func testEspacioDeTrabajoConDosDuenos() throws {
        let context = try context(TreeCenterSchema.lifeModels, "trabajo")

        let project = Project(name: "Tree Center")
        let course = Course(name: "SwiftUI a fondo", totalLessons: 22)
        context.insert(project)
        context.insert(course)

        let projectTask = WorkTask(title: "Arrancarla en el iPhone")
        let courseTask = WorkTask(title: "Módulo 4")
        let note = WorkNote(text: "# Plan\n[ ] Probar el .ipa")
        let idea = WorkIdea(text: "Modo foco")
        let reminder = WorkReminder(kind: .once, hour: 19, minute: 0, date: Date(), label: "Entregar")
        [projectTask, courseTask, note, idea, reminder].forEach { context.insert($0) }

        project.adopt(projectTask)
        project.adopt(note)
        project.adopt(idea)
        course.adopt(courseTask)
        course.adopt(reminder)

        print("[grupo] trabajo: guardando")
        XCTAssertNoThrow(try context.save())
        print("[grupo] trabajo: ok")

        // Cada pieza cae en su dueño y solo en el suyo.
        XCTAssertEqual(project.tasks.count, 1)
        XCTAssertEqual(course.tasks.count, 1)
        XCTAssertEqual(project.notes.count, 1)
        XCTAssertEqual(course.reminders.count, 1)
        XCTAssertTrue(course.notes.isEmpty)

        // Y borrar el proyecto se lleva sus cosas, no las del curso.
        context.delete(project)
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkTask>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkNote>()).count, 0)
    }

    /// Una balda que se borra deja sus libros sin balda, no los borra.
    @MainActor
    func testBorrarUnaBaldaNoBorraLosLibros() throws {
        let context = try context(TreeCenterSchema.lifeModels, "baldas")

        let shelf = Shelf(name: "Ensayo")
        let book = Book(title: "Meditaciones", pages: 180)
        context.insert(shelf)
        context.insert(book)
        book.shelf = shelf
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(shelf.books.count, 1)

        context.delete(shelf)
        XCTAssertNoThrow(try context.save())
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 1)
        XCTAssertNil(book.shelf)
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
