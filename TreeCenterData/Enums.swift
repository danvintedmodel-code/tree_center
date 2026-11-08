import Foundation

// Los tipos cerrados de Tree Center. Viven aparte de los modelos porque varios
// los comparten y porque aqui es donde se escriben las reglas que ninguna
// pantalla deberia poder saltarse.

public enum Weekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public var id: Int { rawValue }

    public var letter: String {
        switch self {
        case .monday: return "L"
        case .tuesday: return "M"
        case .wednesday: return "X"
        case .thursday: return "J"
        case .friday: return "V"
        case .saturday: return "S"
        case .sunday: return "D"
        }
    }

    public var name: String {
        switch self {
        case .monday: return "Lunes"
        case .tuesday: return "Martes"
        case .wednesday: return "Miércoles"
        case .thursday: return "Jueves"
        case .friday: return "Viernes"
        case .saturday: return "Sábado"
        case .sunday: return "Domingo"
        }
    }

    /// Solo el fin de semana se puede dejar libre. La regla vive en el modelo,
    /// no en la pantalla, para que no haya forma de romperla desde ningún sitio.
    public var canBeRestDay: Bool { self == .saturday || self == .sunday }

    /// Calendar cuenta 1 = domingo … 7 = sábado; aquí la semana empieza en lunes.
    /// La conversión va en un solo sitio porque es el error de uno clásico.
    public static func from(calendarWeekday: Int) -> Weekday {
        let shifted = calendarWeekday == 1 ? 7 : calendarWeekday - 1
        return Weekday(rawValue: shifted) ?? .monday
    }

    public static var today: Weekday {
        from(calendarWeekday: Calendar.current.component(.weekday, from: Date()))
    }
}

/// Qué mide la gráfica de progresión del gimnasio.
public enum ProgressMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case topWeight, volume, reps

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .topWeight: return "Peso máx."
        case .volume: return "Volumen"
        case .reps: return "Reps"
        }
    }
}

public enum GarmentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case caps, necklaces, hoodies, shirts, trousers, shoes, socks

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .caps: return "Gorras"
        case .necklaces: return "Collares"
        case .hoodies: return "Sudaderas"
        case .shirts: return "Camisetas"
        case .trousers: return "Pantalones"
        case .shoes: return "Zapatos"
        case .socks: return "Calcetines"
        }
    }
}

public enum WishKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case architecture, sport, gifts, books, travel

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .architecture: return "Arquitectura"
        case .sport: return "Deporte"
        case .gifts: return "Regalos"
        case .books: return "Libros"
        case .travel: return "Viajes"
        }
    }
}

public enum DateKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case birthday, payment, delivery, review

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .birthday: return "Cumpleaños"
        case .payment: return "Pagos"
        case .delivery: return "Entregas"
        case .review: return "Revisiones"
        }
    }
}

public enum ProjectStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case idea, running, paused, closed

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .idea: return "Idea"
        case .running: return "En marcha"
        case .paused: return "Pausado"
        case .closed: return "Cerrado"
        }
    }
}

// MARK: - Finanzas

public enum MovementKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense, income, transfer

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .expense: return "Gasto"
        case .income: return "Ingreso"
        case .transfer: return "Traspaso"
        }
    }

    /// El signo lo pone el tipo de movimiento. El usuario nunca escribe un menos,
    /// y un traspaso no suma ni resta al total: solo cambia el dinero de sitio.
    public var sign: Decimal {
        switch self {
        case .expense: return -1
        case .income: return 1
        case .transfer: return 0
        }
    }
}

/// Una sección dentro de una cartera puede ser solo una etiqueta para agrupar,
/// o una subcartera con tope propio que además puede salir como aro.
public enum WalletKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case wallet, tag

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .wallet: return "Subcartera"
        case .tag: return "Etiqueta"
        }
    }

    public var canHaveCap: Bool { self == .wallet }
    public var canBeARing: Bool { self == .wallet }
}

/// Qué miden los aros y el recuadro de reparto. Los dos siguen al mismo selector.
public enum WalletMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case monthSpend, monthIncome, balance

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .monthSpend: return "Gasto del mes"
        case .monthIncome: return "Ingresos"
        case .balance: return "Saldo"
        }
    }
}

// MARK: - Color

/// Los modelos guardan un color de la paleta, no un hexadecimal. Así el día que
/// se retoque la paleta no hay que migrar ni un dato.
public enum PaletteColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case moss, blue, sand, clay, lilac, neutral

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .moss: return "Musgo"
        case .blue: return "Azul"
        case .sand: return "Arena"
        case .clay: return "Arcilla"
        case .lilac: return "Lila"
        case .neutral: return "Gris"
        }
    }
}

// MARK: - Home

public enum HomeSectionID: String, Codable, CaseIterable, Identifiable, Sendable {
    case gym, food, wardrobe, wishes, calendar, projects, learning, library, finance

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .gym: return "Gimnasio"
        case .food: return "Alimentación"
        case .wardrobe: return "Armario"
        case .wishes: return "Caprichos"
        case .calendar: return "Calendario"
        case .projects: return "Emprendimientos"
        case .learning: return "Formación"
        case .library: return "Biblioteca"
        case .finance: return "Finanzas"
        }
    }
}

public enum WidgetSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case small, wide, large

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .small: return "1 × 1"
        case .wide: return "2 × 1"
        case .large: return "2 × 2"
        }
    }

    public var columns: Int { self == .small ? 1 : 2 }
}
