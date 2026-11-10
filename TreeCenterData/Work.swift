import Foundation
import SwiftData

// El espacio de trabajo que comparten Emprendimientos y Formación: tareas,
// notas, ideas y avisos.
//
// Cada pieza tiene dos dueños posibles, un proyecto o un curso, y solo uno a la
// vez. Así un proyecto y un curso se manejan con las mismas pantallas, y lo que
// se aprenda haciendo una sirve para la otra.

/// Una tarea. Guarda cuándo se cerró, que es lo que alimenta las estadísticas
/// por día, semana y mes.
@Model
public final class WorkTask {
    public var title: String = ""
    public var done: Bool = false
    public var doneAt: Date?
    public var createdAt: Date = Date()
    public var order: Int = 0

    public var project: Project?
    public var course: Course?

    public init(title: String = "", order: Int = 0) {
        self.title = title
        self.order = order
        self.createdAt = Date()
    }

    /// Cerrarla apunta la hora; reabrirla la borra, para que no cuente dos
    /// veces si se cierra otra vez otro día.
    public func toggle(now: Date = Date()) {
        done.toggle()
        doneAt = done ? now : nil
    }
}

/// Una nota del día. Texto plano con cuatro marcas que la pantalla dibuja con
/// formato: «# » título, «• » lista, «[ ] » casilla, «[x] » casilla marcada.
/// Ver NoteMarkup en TreeCenterCore.
@Model
public final class WorkNote {
    public var text: String = ""
    public var createdAt: Date = Date()
    public var editedAt: Date = Date()

    public var project: Project?
    public var course: Course?

    public init(text: String = "", createdAt: Date = Date()) {
        self.text = text
        self.createdAt = createdAt
        self.editedAt = createdAt
    }
}

@Model
public final class WorkIdea {
    public var text: String = ""
    public var createdAt: Date = Date()

    public var project: Project?
    public var course: Course?

    public init(text: String = "") {
        self.text = text
        self.createdAt = Date()
    }
}

/// Un aviso del propio iPhone. No necesita internet ni cuenta: lo programa
/// `UNUserNotificationCenter` en el móvil.
@Model
public final class WorkReminder {
    public var kindRaw: String = ReminderKind.daily.rawValue
    public var hour: Int = 21
    public var minute: Int = 30
    /// Solo para los avisos de un día concreto.
    public var date: Date?
    public var label: String = ""
    /// Con lo que se programa y se cancela en el centro de notificaciones.
    public var identifier: String = UUID().uuidString

    public var project: Project?
    public var course: Course?

    public init(kind: ReminderKind = .daily, hour: Int = 21, minute: Int = 30,
                date: Date? = nil, label: String = "") {
        self.kindRaw = kind.rawValue
        self.hour = hour
        self.minute = minute
        self.date = date
        self.label = label
        self.identifier = UUID().uuidString
    }

    public var kind: ReminderKind { ReminderKind(rawValue: kindRaw) ?? .daily }
}

// MARK: - El dueño del espacio de trabajo

/// Lo que tienen en común un proyecto y un curso para las pantallas del
/// espacio de trabajo.
public protocol WorkspaceOwner: PersistentModel {
    var name: String { get set }
    var tasks: [WorkTask] { get }
    var notes: [WorkNote] { get }
    var ideas: [WorkIdea] { get }
    var reminders: [WorkReminder] { get }

    /// Lo que cuenta como actividad además de tareas y notas. En un curso, las
    /// lecciones hechas; en un proyecto, nada más.
    var extraActivity: [Date] { get }

    func adopt(_ task: WorkTask)
    func adopt(_ note: WorkNote)
    func adopt(_ idea: WorkIdea)
    func adopt(_ reminder: WorkReminder)
}

extension WorkspaceOwner {
    /// Cada cosa hecha, con su fecha: una tarea cerrada, una nota escrita, una
    /// lección. Es la materia prima de las estadísticas.
    public var activityDates: [Date] {
        tasks.compactMap(\.doneAt) + notes.map(\.createdAt) + extraActivity
    }

    public var orderedTasks: [WorkTask] {
        tasks.sorted { lhs, rhs in
            // Pendientes arriba; dentro de cada grupo, en el orden de creación.
            if lhs.done != rhs.done { return !lhs.done }
            return lhs.order < rhs.order
        }
    }

    public var recentNotes: [WorkNote] { notes.sorted { $0.createdAt > $1.createdAt } }
    public var recentIdeas: [WorkIdea] { ideas.sorted { $0.createdAt > $1.createdAt } }
    public var doneShare: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter(\.done).count) / Double(tasks.count)
    }
}

extension Project: WorkspaceOwner {
    public var extraActivity: [Date] { [] }
    public func adopt(_ task: WorkTask) { task.project = self }
    public func adopt(_ note: WorkNote) { note.project = self }
    public func adopt(_ idea: WorkIdea) { idea.project = self }
    public func adopt(_ reminder: WorkReminder) { reminder.project = self }
}

extension Course: WorkspaceOwner {
    public var extraActivity: [Date] { lessonLog }
    public func adopt(_ task: WorkTask) { task.course = self }
    public func adopt(_ note: WorkNote) { note.course = self }
    public func adopt(_ idea: WorkIdea) { idea.course = self }
    public func adopt(_ reminder: WorkReminder) { reminder.course = self }
}
