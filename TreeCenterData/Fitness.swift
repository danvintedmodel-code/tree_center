import Foundation
import SwiftData

// Gimnasio. La rutina es el plan; el entreno es lo que de verdad hiciste.
// Se guardan separados a propósito: cambiar la rutina no debe reescribir tu historial.

@Model
public final class Exercise {
    public var name: String = ""
    /// Nombre del archivo Lottie con la personita haciendo el ejercicio.
    public var animationName: String?
    /// Tres puntos de técnica, no un tratado.
    public var technique: [String] = []
    public var createdAt: Date = Date()

    /// Nullify y no cascade: borrar un ejercicio del catálogo no puede llevarse
    /// por delante el historial de lo que levantaste con él.
    @Relationship(deleteRule: .nullify, inverse: \SetEntry.exercise)
    public var sets: [SetEntry] = []

    public init(name: String = "", animationName: String? = nil, technique: [String] = []) {
        self.name = name
        self.animationName = animationName
        self.technique = technique
        self.createdAt = Date()
    }
}

/// Una sesión tipo: "Empuje", "Tirón", "Pierna".
@Model
public final class WorkoutTemplate {
    public var name: String = ""
    public var order: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.template)
    public var plan: [PlannedExercise] = []

    public init(name: String = "", order: Int = 0) {
        self.name = name
        self.order = order
    }

    public var orderedPlan: [PlannedExercise] { plan.sorted { $0.order < $1.order } }
}

@Model
public final class PlannedExercise {
    public var order: Int = 0
    public var sets: Int = 3
    public var reps: Int = 10
    public var weight: Double?

    public var exercise: Exercise?
    public var template: WorkoutTemplate?

    public init(exercise: Exercise? = nil, order: Int = 0, sets: Int = 3, reps: Int = 10, weight: Double? = nil) {
        self.exercise = exercise
        self.order = order
        self.sets = sets
        self.reps = reps
        self.weight = weight
    }
}

/// La semana. Siete días, cada uno con su sesión o en descanso.
@Model
public final class RoutineDay {
    /// Guardado como Int porque SwiftData ordena y filtra mejor por un entero.
    public var weekdayRaw: Int = 1
    public var template: WorkoutTemplate?
    public var routine: Routine?

    public init(weekday: Weekday = .monday, template: WorkoutTemplate? = nil) {
        self.weekdayRaw = weekday.rawValue
        self.template = template
    }

    public var weekday: Weekday { Weekday(rawValue: weekdayRaw) ?? .monday }

    public var isRestDay: Bool { template == nil }

    /// Quitar un día solo vale en sábado y domingo. Lo comprueba el modelo.
    @discardableResult
    public func makeRestDay() -> Bool {
        guard weekday.canBeRestDay else { return false }
        template = nil
        return true
    }
}

@Model
public final class Routine {
    public var name: String = "Mi rutina"
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \RoutineDay.routine)
    public var days: [RoutineDay] = []

    public init(name: String = "Mi rutina", days: [RoutineDay] = []) {
        self.name = name
        self.days = days
        self.createdAt = Date()
    }

    public var orderedDays: [RoutineDay] { days.sorted { $0.weekdayRaw < $1.weekdayRaw } }

    public var restDays: [RoutineDay] { days.filter(\.isRestDay) }

    /// Como mucho dos descansos, y solo en fin de semana.
    public var isValid: Bool {
        restDays.count <= 2 && restDays.allSatisfy { $0.weekday.canBeRestDay }
    }

    public func day(_ weekday: Weekday) -> RoutineDay? {
        days.first { $0.weekdayRaw == weekday.rawValue }
    }
}

/// Un entreno realmente hecho.
@Model
public final class Workout {
    public var date: Date = Date()
    public var templateName: String = ""
    public var durationMinutes: Int?
    public var finished: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.workout)
    public var sets: [SetEntry] = []

    public init(date: Date = Date(), templateName: String = "", durationMinutes: Int? = nil) {
        self.date = date
        self.templateName = templateName
        self.durationMinutes = durationMinutes
    }

    public var volume: Double {
        sets.filter(\.done).reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps) }
    }
}

@Model
public final class SetEntry {
    public var index: Int = 1
    public var weight: Double?
    public var reps: Int = 0
    public var done: Bool = false
    public var doneAt: Date?

    public var workout: Workout?
    public var exercise: Exercise?

    public init(index: Int = 1, weight: Double? = nil, reps: Int = 0, exercise: Exercise? = nil) {
        self.index = index
        self.weight = weight
        self.reps = reps
        self.exercise = exercise
    }
}

@Model
public final class BodyMeasurement {
    public var date: Date = Date()
    public var weightKg: Double?
    public var waistCm: Double?

    @Attribute(.externalStorage) public var photo: Data?

    public init(date: Date = Date(), weightKg: Double? = nil, waistCm: Double? = nil) {
        self.date = date
        self.weightKg = weightKg
        self.waistCm = waistCm
    }
}
