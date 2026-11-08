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

@Model
public final class Project {
    public var name: String = ""
    public var statusRaw: String = ProjectStatus.idea.rawValue
    public var progress: Double = 0
    public var nextStep: String = ""
    public var nextStepDate: Date?
    public var startedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    public var tasks: [ProjectTask] = []

    @Relationship(deleteRule: .cascade, inverse: \DecisionNote.project)
    public var decisions: [DecisionNote] = []

    public init(name: String = "", status: ProjectStatus = .idea,
                progress: Double = 0, nextStep: String = "") {
        self.name = name
        self.statusRaw = status.rawValue
        self.progress = progress
        self.nextStep = nextStep
        self.startedAt = Date()
    }

    public var status: ProjectStatus { ProjectStatus(rawValue: statusRaw) ?? .idea }
    public var openTasks: Int { tasks.filter { !$0.done }.count }
}

@Model
public final class ProjectTask {
    public var title: String = ""
    public var done: Bool = false
    public var order: Int = 0
    public var project: Project?

    public init(title: String = "", done: Bool = false, order: Int = 0) {
        self.title = title
        self.done = done
        self.order = order
    }
}

/// El diario de decisiones: por qué se decidió lo que se decidió, con fecha.
/// Es lo que te salva dentro de seis meses.
@Model
public final class DecisionNote {
    public var date: Date = Date()
    public var text: String = ""
    public var project: Project?

    public init(date: Date = Date(), text: String = "") {
        self.date = date
        self.text = text
    }
}

// MARK: - Formación

@Model
public final class Course {
    public var name: String = ""
    public var totalLessons: Int = 1
    public var currentLesson: Int = 0
    public var lastTouched: Date?
    public var finishedAt: Date?

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
}

@Model
public final class Topic {
    public var name: String = ""
    public var order: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \StudyNote.topic)
    public var notes: [StudyNote] = []

    public init(name: String = "", order: Int = 0) {
        self.name = name
        self.order = order
    }
}

@Model
public final class StudyNote {
    public var title: String = ""
    public var body: String = ""
    public var tags: [String] = []
    /// De dónde salió. Es lo que permite que un subrayado de Biblioteca llegue
    /// aquí con su origen puesto en vez de aparecer huérfano.
    public var source: String = ""
    public var createdAt: Date = Date()
    public var topic: Topic?

    public init(title: String = "", body: String = "", tags: [String] = [], source: String = "") {
        self.title = title
        self.body = body
        self.tags = tags
        self.source = source
        self.createdAt = Date()
    }
}

// MARK: - Biblioteca

@Model
public final class Book {
    public var title: String = ""
    public var author: String = ""
    public var pages: Int = 1
    public var currentPage: Int = 0
    public var shelf: String = ""
    public var colorRaw: String = PaletteColor.neutral.rawValue
    public var readingNow: Bool = false
    public var finishedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Highlight.book)
    public var highlights: [Highlight] = []

    public init(title: String = "", author: String = "", pages: Int = 1,
                currentPage: Int = 0, shelf: String = "", color: PaletteColor = .neutral) {
        self.title = title
        self.author = author
        self.pages = pages
        self.currentPage = currentPage
        self.shelf = shelf
        self.colorRaw = color.rawValue
    }

    public var color: PaletteColor { PaletteColor(rawValue: colorRaw) ?? .neutral }

    public var progress: Double {
        guard pages > 0 else { return 0 }
        return min(1, Double(currentPage) / Double(pages))
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
    public var price: Decimal?
    public var link: String = ""
    public var notes: String = ""
    public var createdAt: Date = Date()
    public var block: WishBlock?

    @Attribute(.externalStorage) public var image: Data?

    public init(name: String = "", price: Decimal? = nil, link: String = "") {
        self.name = name
        self.price = price
        self.link = link
        self.createdAt = Date()
    }
}

@Model
public final class Place {
    public var name: String = ""
    public var country: String = ""
    public var whenNote: String = ""
    public var budget: Decimal?
    public var notes: String = ""
    public var order: Int = 0

    @Attribute(.externalStorage) public var image: Data?

    public init(name: String = "", country: String = "", whenNote: String = "",
                budget: Decimal? = nil, order: Int = 0) {
        self.name = name
        self.country = country
        self.whenNote = whenNote
        self.budget = budget
        self.order = order
    }
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
