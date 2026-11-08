import Foundation
import SwiftData

// Alimentación. La estantería son libros, los libros tienen capítulos y los
// capítulos fichas. Lo que comes hoy se apunta aparte: una receta es una
// plantilla, y una comida es un hecho con fecha.

@Model
public final class RecipeBook {
    public var name: String = ""
    public var colorRaw: String = PaletteColor.moss.rawValue
    public var order: Int = 0
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    public var chapters: [Chapter] = []

    public init(name: String = "", color: PaletteColor = .moss, order: Int = 0) {
        self.name = name
        self.colorRaw = color.rawValue
        self.order = order
        self.createdAt = Date()
    }

    public var color: PaletteColor { PaletteColor(rawValue: colorRaw) ?? .moss }
    public var orderedChapters: [Chapter] { chapters.sorted { $0.order < $1.order } }
    public var recipeCount: Int { chapters.reduce(0) { $0 + $1.recipes.count } }
}

@Model
public final class Chapter {
    public var name: String = ""
    public var order: Int = 0
    public var book: RecipeBook?

    @Relationship(deleteRule: .cascade, inverse: \Recipe.chapter)
    public var recipes: [Recipe] = []

    public init(name: String = "", order: Int = 0) {
        self.name = name
        self.order = order
    }

    public var orderedRecipes: [Recipe] { recipes.sorted { $0.order < $1.order } }
}

@Model
public final class Recipe {
    public var name: String = ""
    public var order: Int = 0
    public var kcal: Int = 0
    public var proteinG: Int = 0
    public var carbsG: Int = 0
    public var fatG: Int = 0
    public var steps: String = ""
    public var createdAt: Date = Date()

    /// Fuera de la base: una foto de comida no tiene por qué cargarse cada vez
    /// que se lista un capítulo.
    @Attribute(.externalStorage) public var image: Data?

    public var chapter: Chapter?

    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    public var ingredients: [Ingredient] = []

    public init(name: String = "", kcal: Int = 0, proteinG: Int = 0,
                carbsG: Int = 0, fatG: Int = 0, order: Int = 0) {
        self.name = name
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.order = order
        self.createdAt = Date()
    }
}

@Model
public final class Ingredient {
    public var name: String = ""
    public var amount: String = ""
    public var order: Int = 0
    public var recipe: Recipe?

    public init(name: String = "", amount: String = "", order: Int = 0) {
        self.name = name
        self.amount = amount
        self.order = order
    }
}

/// Lo que has comido hoy. Copia los macros en vez de apuntar a la receta: si
/// mañana cambias la receta, lo que comiste el martes no debe cambiar contigo.
@Model
public final class MealEntry {
    public var date: Date = Date()
    public var name: String = ""
    public var kcal: Int = 0
    public var proteinG: Int = 0
    public var carbsG: Int = 0
    public var fatG: Int = 0

    public init(date: Date = Date(), name: String = "", kcal: Int = 0,
                proteinG: Int = 0, carbsG: Int = 0, fatG: Int = 0) {
        self.date = date
        self.name = name
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }

    public convenience init(copying recipe: Recipe, on date: Date = Date()) {
        self.init(date: date, name: recipe.name, kcal: recipe.kcal,
                  proteinG: recipe.proteinG, carbsG: recipe.carbsG, fatG: recipe.fatG)
    }
}

@Model
public final class NutritionGoal {
    public var dailyKcal: Int = 2700
    public var dailyProteinG: Int = 160

    public init(dailyKcal: Int = 2700, dailyProteinG: Int = 160) {
        self.dailyKcal = dailyKcal
        self.dailyProteinG = dailyProteinG
    }
}
