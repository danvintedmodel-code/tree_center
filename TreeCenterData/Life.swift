import Foundation
import SwiftData

// Calendario, emprendimientos, formación, biblioteca y caprichos.
// Secciones distintas, modelos pequeños, un archivo para no dispersarlos.

// MARK: - Calendario

@Model
public final class ImportantDate {
    public var title: String = ""
    public var date: Date = Date()
    public var kindRaw: String = DateKind.payment.rawValue
    public var repeatsYearly: Bool = false
    public var remindDaysBefore: Int = 1
    public var notes: String = ""

    public init(title: String = "", date: Date = Date(), kind: DateKind = .payment,
                repeatsYearly: Bool = false, remindDaysBefore: Int = 1) {
        self.title = title
        self.date = date
        self.kindRaw = kind.rawValue
        self.repeatsYearly = repeatsYearly
        self.remindDaysBefore = remindDaysBefore
    }

    public var kind: DateKind { DateKind(rawValue: kindRaw) ?? .payment }

    public var color: PaletteColor {
        switch kind {
        case .birthday: return .blue
        case .payment: return .sand
        case .delivery: return .clay
        case .review: return .lilac
        }
    }
}

// MARK: - Emprendimientos

/// Un proyecto. Sus tareas, notas, ideas y avisos viven en el espacio de
/// trabajo compartido con los cursos (Work.swift).
@Model
public final class Project {
    public var name: String = ""
    public var statusRaw: String = ProjectStatus.idea.rawValue
    public var startedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WorkTask.project)
    public var tasks: [WorkTask] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkNote.project)
    public var notes: [WorkNote] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkIdea.project)
    public var ideas: [WorkIdea] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkReminder.project)
    public var reminders: [WorkReminder] = []

    public init(name: String = "", status: ProjectStatus = .idea) {
        self.name = name
        self.statusRaw = status.rawValue
        self.startedAt = Date()
    }

    public var status: ProjectStatus { ProjectStatus(rawValue: statusRaw) ?? .idea }
    public var openTasks: Int { tasks.filter { !$0.done }.count }
}

// MARK: - Formación

@Model
public final class Course {
    public var name: String = ""
    public var totalLessons: Int = 1
    public var currentLesson: Int = 0
    public var finishedAt: Date?

    /// La fecha de cada lección hecha. Sin ella las estadísticas de un curso
    /// solo sabrían cuántas llevas, no cuándo las hiciste.
    public var lessonLog: [Date] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkTask.course)
    public var tasks: [WorkTask] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkNote.course)
    public var notes: [WorkNote] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkIdea.course)
    public var ideas: [WorkIdea] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkReminder.course)
    public var reminders: [WorkReminder] = []

    public init(name: String = "", totalLessons: Int = 1, currentLesson: Int = 0) {
        self.name = name
        self.totalLessons = totalLessons
        self.currentLesson = currentLesson
    }

    public var progress: Double {
        guard totalLessons > 0 else { return 0 }
        return min(1, Double(currentLesson) / Double(totalLessons))
    }

    /// Un curso terminado no desaparece: se queda al 100 % como registro.
    public var isFinished: Bool { finishedAt != nil || currentLesson >= totalLessons }

    /// Una lección más, con su fecha. Al llegar a la última, el curso se cierra.
    public func completeLesson(now: Date = Date()) {
        guard currentLesson < totalLessons else { return }
        currentLesson += 1
        lessonLog.append(now)
        if currentLesson >= totalLessons { finishedAt = now }
    }
}

// MARK: - Biblioteca

/// Una balda: una categoría de la estantería. Las nuevas van debajo.
@Model
public final class Shelf {
    public var name: String = ""
    public var order: Int = 0

    /// Nullify: borrar una balda no borra sus libros, los deja sin balda.
    @Relationship(deleteRule: .nullify, inverse: \Book.shelf)
    public var books: [Book] = []

    public init(name: String = "", order: Int = 0) {
        self.name = name
        self.order = order
    }

    public var orderedBooks: [Book] { books.sorted { $0.addedAt < $1.addedAt } }
}

@Model
public final class Book {
    public var title: String = ""
    public var author: String = ""
    public var pages: Int = 1
    public var currentPage: Int = 0
    public var colorRaw: String = PaletteColor.neutral.rawValue
    public var readingNow: Bool = false
    public var finishedAt: Date?
    public var addedAt: Date = Date()
    /// El código de barras del libro. Con él se busca la tapa de verdad.
    public var isbn: String = ""

    /// La tapa: la del escaneo, o una foto. Sin ella se dibuja una con el color.
    @Attribute(.externalStorage) public var cover: Data?

    public var shelf: Shelf?

    @Relationship(deleteRule: .cascade, inverse: \Highlight.book)
    public var highlights: [Highlight] = []

    public init(title: String = "", author: String = "", pages: Int = 1,
                currentPage: Int = 0, color: PaletteColor = .neutral, isbn: String = "") {
        self.title = title
        self.author = author
        self.pages = pages
        self.currentPage = currentPage
        self.colorRaw = color.rawValue
        self.isbn = isbn
        self.addedAt = Date()
    }

    public var color: PaletteColor { PaletteColor(rawValue: colorRaw) ?? .neutral }

    public var progress: Double {
        guard pages > 0 else { return 0 }
        return min(1, Double(currentPage) / Double(pages))
    }

    public var isFinished: Bool { currentPage >= pages }

    /// Avanza páginas sin pasarse, y cierra el libro al llegar al final.
    public func read(_ delta: Int, now: Date = Date()) {
        currentPage = min(pages, max(0, currentPage + delta))
        if currentPage >= pages && finishedAt == nil { finishedAt = now }
    }

    /// El ancho del lomo lo dan las páginas. Es el detalle que hace que el
    /// estante parezca un estante.
    public var spineWidth: Double { min(44, max(20, Double(pages) / 16)) }
}


@Model
public final class Highlight {
    public var text: String = ""
    public var page: Int = 0
    public var createdAt: Date = Date()
    public var sentToNotes: Bool = false
    public var book: Book?

    public init(text: String = "", page: Int = 0) {
        self.text = text
        self.page = page
        self.createdAt = Date()
    }
}

// MARK: - Caprichos

@Model
public final class WishBlock {
    public var kindRaw: String = WishKind.gifts.rawValue
    public var order: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \WishItem.block)
    public var items: [WishItem] = []

    public init(kind: WishKind = .gifts, order: Int = 0) {
        self.kindRaw = kind.rawValue
        self.order = order
    }

    public var kind: WishKind { WishKind(rawValue: kindRaw) ?? .gifts }
}

@Model
public final class WishItem {
    public var name: String = ""
    /// En céntimos, como todo el dinero de la app. Ver Money.swift.
    public var priceCents: Int?
    public var link: String = ""
    public var notes: String = ""
    public var createdAt: Date = Date()
    public var block: WishBlock?

    @Attribute(.externalStorage) public var image: Data?

    public init(name: String = "", priceCents: Int? = nil, link: String = "") {
        self.name = name
        self.priceCents = priceCents
        self.link = link
        self.createdAt = Date()
    }

    public var price: Decimal? { priceCents.map(Cents.decimal) }
}

@Model
public final class Place {
    public var name: String = ""
    public var country: String = ""
    public var whenNote: String = ""
    public var budgetCents: Int?
    public var notes: String = ""
    public var order: Int = 0

    @Attribute(.externalStorage) public var image: Data?

    public init(name: String = "", country: String = "", whenNote: String = "",
                budgetCents: Int? = nil, order: Int = 0) {
        self.name = name
        self.country = country
        self.whenNote = whenNote
        self.budgetCents = budgetCents
        self.order = order
    }

    public var budget: Decimal? { budgetCents.map(Cents.decimal) }
}

// MARK: - Home

@Model
public final class HomeWidget {
    public var sectionRaw: String = HomeSectionID.gym.rawValue
    /// Qué cara tiene: "ring", "week", "number"… Cada sección trae las suyas.
    public var design: String = "ring"
    public var sizeRaw: String = WidgetSize.large.rawValue
    public var order: Int = 0

    public init(section: HomeSectionID = .gym, design: String = "ring",
                size: WidgetSize = .large, order: Int = 0) {
        self.sectionRaw = section.rawValue
        self.design = design
        self.sizeRaw = size.rawValue
        self.order = order
    }

    public var section: HomeSectionID { HomeSectionID(rawValue: sectionRaw) ?? .gym }
    public var size: WidgetSize { WidgetSize(rawValue: sizeRaw) ?? .large }
}
