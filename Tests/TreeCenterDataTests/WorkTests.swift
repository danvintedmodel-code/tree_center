import Foundation
import SwiftData
import XCTest
@testable import TreeCenterData

// Las reglas pequeñas del espacio de trabajo y la biblioteca: lo que alimenta
// las estadísticas tiene que apuntar la fecha justa, ni de más ni de menos.

final class WorkTests: XCTestCase {

    private var containers: [ModelContainer] = []
    private var urls: [URL] = []

    override func tearDown() {
        containers = []
        for url in urls { try? FileManager.default.removeItem(at: url) }
        urls = []
        super.tearDown()
    }

    /// El contenedor se retiene: un contexto cuyo contenedor ya se liberó se
    /// lleva por delante el proceso entero. Ver SchemaTests.
    @MainActor
    private func context() throws -> ModelContext {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tc-trabajo-\(UUID().uuidString).store")
        urls.append(url)
        let container = try TreeCenterSchema.container(models: TreeCenterSchema.lifeModels, at: url)
        containers.append(container)
        return container.mainContext
    }

    @MainActor
    func testCerrarYReabrirUnaTareaNoCuentaDosVeces() throws {
        let context = try context()
        let project = Project(name: "P")
        let task = WorkTask(title: "T")
        context.insert(project)
        context.insert(task)
        project.adopt(task)

        let monday = Date(timeIntervalSince1970: 1_800_000_000)
        task.toggle(now: monday)
        XCTAssertEqual(task.doneAt, monday)
        XCTAssertEqual(project.activityDates.count, 1)

        // Reabrirla borra la fecha: si se vuelve a cerrar otro día, cuenta ese
        // día y no los dos.
        task.toggle(now: monday.addingTimeInterval(3_600))
        XCTAssertNil(task.doneAt)
        XCTAssertEqual(project.activityDates.count, 0)

        let thursday = monday.addingTimeInterval(3 * 86_400)
        task.toggle(now: thursday)
        XCTAssertEqual(project.activityDates, [thursday])
    }

    @MainActor
    func testUnaLeccionApuntaSuFechaYCierraElCursoAlFinal() throws {
        let context = try context()
        let course = Course(name: "C", totalLessons: 2, currentLesson: 0)
        context.insert(course)

        let day = Date(timeIntervalSince1970: 1_800_000_000)
        course.completeLesson(now: day)
        XCTAssertEqual(course.currentLesson, 1)
        XCTAssertEqual(course.lessonLog, [day])
        XCTAssertNil(course.finishedAt)

        course.completeLesson(now: day)
        XCTAssertTrue(course.isFinished)
        XCTAssertEqual(course.finishedAt, day)

        // Pasado el final no suma lecciones fantasma.
        course.completeLesson(now: day)
        XCTAssertEqual(course.currentLesson, 2)
        XCTAssertEqual(course.lessonLog.count, 2)

        // Y las lecciones cuentan como actividad del curso.
        XCTAssertEqual(course.activityDates.count, 2)
    }

    @MainActor
    func testLeerNoSePasaDeLaUltimaPaginaNiBajaDeCero() throws {
        let context = try context()
        let book = Book(title: "B", pages: 100, currentPage: 90)
        context.insert(book)

        book.read(20)
        XCTAssertEqual(book.currentPage, 100)
        XCTAssertTrue(book.isFinished)
        XCTAssertNotNil(book.finishedAt)

        book.read(-500)
        XCTAssertEqual(book.currentPage, 0)
    }

    @MainActor
    func testLasTareasPendientesVanArriba() throws {
        let context = try context()
        let project = Project(name: "P")
        context.insert(project)
        let first = WorkTask(title: "primera", order: 0)
        let second = WorkTask(title: "segunda", order: 1)
        [first, second].forEach { context.insert($0); project.adopt($0) }

        first.toggle()
        XCTAssertEqual(project.orderedTasks.map(\.title), ["segunda", "primera"])
    }
}
