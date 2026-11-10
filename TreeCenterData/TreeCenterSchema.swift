import Foundation
import SwiftData

// El esquema completo y el arranque del almacén.
//
// La lista de modelos se escribe a mano a propósito: si alguien añade un @Model
// y se olvida de ponerlo aquí, no se guarda, y es mejor que eso salte en la
// prueba que lo recorre que seis meses después con datos reales dentro.

public enum TreeCenterSchema {

    public static let models: [any PersistentModel.Type] = [
        // Gimnasio
        Exercise.self, WorkoutTemplate.self, PlannedExercise.self,
        RoutineDay.self, Routine.self, Workout.self, SetEntry.self, BodyMeasurement.self,
        // Alimentación
        RecipeBook.self, Chapter.self, Recipe.self, Ingredient.self,
        MealEntry.self, NutritionGoal.self,
        // Armario
        Garment.self, Outfit.self,
        // Finanzas
        Wallet.self, WalletSection.self, Movement.self, FinanceSettings.self,
        // Resto
        ImportantDate.self, Project.self, Course.self,
        WorkTask.self, WorkNote.self, WorkIdea.self, WorkReminder.self,
        Shelf.self,
        Book.self, Highlight.self,
        WishBlock.self, WishItem.self, Place.self,
        HomeWidget.self
    ]

    /// El almacén de la app.
    ///
    /// La ruta se escribe a mano (ver `StoreFiles`) en vez de dejar que
    /// SwiftData elija: una copia de seguridad necesita saber qué archivos son
    /// suyos, y el sitio por defecto no está prometido por escrito en ningún
    /// sitio.
    ///
    /// `cloud` pide la sincronización con iCloud. **Necesita el entitlement de
    /// CloudKit en el target**, y sin él esto lanza en vez de arrancar en local
    /// sin avisar: quien llama decide qué hacer con el error.
    public static func container(inMemory: Bool = false,
                                 cloud: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)

        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            StoreFiles.ensureDirectory()
            configuration = ModelConfiguration(schema: schema,
                                               url: StoreFiles.storeURL,
                                               cloudKitDatabase: cloud ? .automatic : .none)
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Un almacén en un archivo concreto. Lo usan las pruebas: varios modelos
    /// guardan imágenes fuera de la base con `.externalStorage`, y eso necesita
    /// un sitio de verdad donde escribirlas.
    public static func container(at url: URL) throws -> ModelContainer {
        try container(models: models, at: url)
    }

    /// Un almacén con solo una parte de los modelos.
    ///
    /// Existe para poder aislar grupos en las pruebas: cuando el esquema entero
    /// revienta al guardar, abrirlo por trozos es la única forma rápida de saber
    /// qué trozo lo rompe. En la app siempre se usa el esquema completo.
    public static func container(models subset: [any PersistentModel.Type],
                                 at url: URL) throws -> ModelContainer {
        let schema = Schema(subset)
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // Los grupos, tal y como están repartidos por archivos.
    public static let fitnessModels: [any PersistentModel.Type] = [
        Exercise.self, WorkoutTemplate.self, PlannedExercise.self,
        RoutineDay.self, Routine.self, Workout.self, SetEntry.self, BodyMeasurement.self
    ]

    public static let foodModels: [any PersistentModel.Type] = [
        RecipeBook.self, Chapter.self, Recipe.self, Ingredient.self,
        MealEntry.self, NutritionGoal.self
    ]

    public static let wardrobeModels: [any PersistentModel.Type] = [
        Garment.self, Outfit.self
    ]

    public static let financeModels: [any PersistentModel.Type] = [
        Wallet.self, WalletSection.self, Movement.self, FinanceSettings.self
    ]

    public static let lifeModels: [any PersistentModel.Type] = [
        ImportantDate.self, Project.self, Course.self,
        WorkTask.self, WorkNote.self, WorkIdea.self, WorkReminder.self,
        Shelf.self,
        Book.self, Highlight.self,
        WishBlock.self, WishItem.self, Place.self,
        HomeWidget.self
    ]

    // MARK: - Primer arranque

    /// Lo mínimo para que la app no se abra vacía: la semana, las tres carteras
    /// y los widgets del inicio. No inventa datos tuyos, solo el armazón.
    public static func seedIfEmpty(_ context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Routine>())
        guard existing.isEmpty else { return }

        // Gimnasio: empuje, tirón y pierna de lunes a viernes.
        // Las sesiones vienen con ejercicios puestos para que la pantalla no se
        // abra vacía. Es un punto de partida, no una rutina pensada para nadie:
        // se edita entera desde la propia app.
        let push = WorkoutTemplate(name: "Empuje", order: 0)
        let pull = WorkoutTemplate(name: "Tirón", order: 1)
        let legs = WorkoutTemplate(name: "Pierna", order: 2)
        [push, pull, legs].forEach(context.insert)

        let starter: [(WorkoutTemplate, [(String, Int, Int)])] = [
            (push, [("Press banca", 4, 8), ("Press militar", 3, 10),
                    ("Fondos", 3, 12), ("Elevaciones laterales", 3, 15)]),
            (pull, [("Dominadas", 4, 8), ("Remo con barra", 4, 10),
                    ("Curl con barra", 3, 12), ("Face pull", 3, 15)]),
            (legs, [("Sentadilla", 4, 8), ("Peso muerto rumano", 3, 10),
                    ("Prensa", 3, 12), ("Gemelos", 4, 15)])
        ]

        for (template, rows) in starter {
            for (index, row) in rows.enumerated() {
                let exercise = Exercise(name: row.0)
                context.insert(exercise)
                let planned = PlannedExercise(exercise: exercise, order: index,
                                              sets: row.1, reps: row.2)
                context.insert(planned)
                planned.template = template
            }
        }

        let plan: [Weekday: WorkoutTemplate?] = [
            .monday: push, .tuesday: pull, .wednesday: legs,
            .thursday: push, .friday: pull, .saturday: nil, .sunday: nil
        ]
        let days = Weekday.allCases.map { RoutineDay(weekday: $0, template: plan[$0] ?? nil) }
        days.forEach(context.insert)

        let routine = Routine(name: "Mi rutina", days: days)
        context.insert(routine)

        // Alimentación
        context.insert(NutritionGoal())
        let recipes = RecipeBook(name: "Recetas", color: .moss, order: 0)
        context.insert(recipes)
        ["Desayunos", "Comidas", "Cenas", "Batidos", "Fuera de casa"]
            .enumerated()
            .forEach { index, name in
                let chapter = Chapter(name: name, order: index)
                context.insert(chapter)
                chapter.book = recipes
            }

        // Finanzas
        let daily = Wallet(name: "Diario", color: .moss, monthlyCapCents: 50_000, order: 0)
        let savings = Wallet(name: "Ahorro", color: .blue, order: 1)
        let treats = Wallet(name: "Caprichos", color: .clay, monthlyCapCents: 15_000, order: 2)
        [daily, savings, treats].forEach(context.insert)
        context.insert(FinanceSettings())

        // Caprichos: un bloque por tema.
        WishKind.allCases.enumerated().forEach { index, kind in
            context.insert(WishBlock(kind: kind, order: index))
        }

        // Inicio: el gimnasio ocupa la fila entera y comida y calendario van
        // uno al lado del otro. Dos de 1×1 caben en una fila; un 2×1 no.
        context.insert(HomeWidget(section: .gym, design: "ring", size: .large, order: 0))
        context.insert(HomeWidget(section: .food, design: "macros", size: .small, order: 1))
        context.insert(HomeWidget(section: .calendar, design: "next", size: .small, order: 2))

        try context.save()
    }
}

public extension Calendar {
    /// El mes en curso, que es el periodo de "entra", "sale" y el tope.
    /// El saldo no usa esto: el saldo es acumulado y no se reinicia.
    func monthInterval(containing date: Date = Date()) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}
