import SwiftData
import SwiftUI
import TreeCenterData

// El centro del árbol: widgets arriba, barra de secciones abajo y los cuatro
// botones pegados al borde. Las cifras salen ya de SwiftData, no del aire.
//
// Los iconos son SF Symbols de momento. El set propio de línea de 1,4 px entra
// cuando esté dibujado; cambiar uno por otro es tocar solo `symbol(for:)`.

struct HomeView: View {
    /// Hace falta aquí solo para Ajustes, que es desde donde se cambia el trazo.
    let lock: LockController

    @Query private var routines: [Routine]
    @Query private var workouts: [Workout]
    @Query private var meals: [MealEntry]
    @Query private var goals: [NutritionGoal]
    @Query(sort: \ImportantDate.date) private var importantDates: [ImportantDate]

    /// Esta es la lista que manda: lo que hay aquí es lo que se dibuja arriba, en
    /// este orden. Se edita en la galería, no en el código.
    @Query(sort: \HomeWidget.order) private var widgets: [HomeWidget]

    @Query(sort: \Wallet.order) private var wallets: [Wallet]
    @Query private var garments: [Garment]
    @Query private var wishItems: [WishItem]
    @Query private var projects: [Project]
    @Query private var courses: [Course]
    @Query private var books: [Book]

    @State private var selectedTab = 0
    @State private var addingMovement = false

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    // Filas armadas a mano y no con LazyVGrid: `gridCellColumns`
                    // solo lo entiende `Grid`, y en una malla perezosa un widget
                    // ancho no ocupa dos columnas, se queda en una.
                    ForEach(Array(widgetRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 12) {
                            ForEach(row) { widget in
                                widgetCard(widget)
                            }
                            if row.count == 1 && row[0].size == .small {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }

                    NavigationLink { WidgetsView() } label: {
                        Text(widgets.isEmpty ? "Añadir widget" : "Editar widgets")
                            .font(TCFont.font(14, .medium))
                            .foregroundStyle(TCColor.textSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: TCRadius.control, style: .continuous)
                                    .strokeBorder(TCColor.lineStrong,
                                                  style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            // Si todo está arriba como widget, la barra desaparece en vez de
            // quedarse como una tira vacía.
            if !barSections.isEmpty {
                sectionsBar
                    .padding(.horizontal, TCSpace.gutter)
                    .padding(.bottom, 14)
            }

            tabBar
                .padding(.horizontal, TCSpace.gutter)
        }
        .background(TCColor.bg)
        .sheet(isPresented: $addingMovement) {
            MovementEditorView()
                .presentationDetents([.large])
        }
    }

    // MARK: - Lo que dicen los datos

    private var routine: Routine? { routines.first }

    private var todayPlan: RoutineDay? { routine?.day(.today) }

    private var trainingDays: Int {
        routine?.days.filter { !$0.isRestDay }.count ?? 0
    }

    private var week: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)
            ?? DateInterval(start: .now, duration: 0)
    }

    private var workoutsThisWeek: [Workout] {
        workouts.filter { $0.finished && week.contains($0.date) }
    }

    private var weekdaysTrained: Set<Int> {
        Set(workoutsThisWeek.map {
            Weekday.from(calendarWeekday: Calendar.current.component(.weekday, from: $0.date)).rawValue
        })
    }

    private var sessionsDone: Int { workoutsThisWeek.count }

    private var todayKcal: Int {
        meals.filter { Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.kcal }
    }

    private var goalKcal: Int { goals.first?.dailyKcal ?? 2700 }

    private var nextDate: ImportantDate? {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return importantDates.first { $0.date >= startOfToday }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tree Center").tcTitle()
                Text(todayLine).tcBody()
            }
            Spacer()
            Circle()
                .fill(TCColor.card)
                .overlay(Circle().stroke(TCColor.line, lineWidth: 1))
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(TCColor.textSoft)
                )
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, TCSpace.gutter)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    private var todayLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE d 'de' MMMM"
        return f.string(from: .now)
    }

    // MARK: - Widgets

    /// Dos columnas: un widget de 1×1 ocupa media fila, los de 2×1 y 2×2 la
    /// entera. Un 1×1 solo al final se queda con su hueco al lado en vez de
    /// estirarse al ancho completo.
    private var widgetRows: [[HomeWidget]] {
        var rows: [[HomeWidget]] = []
        var pending: [HomeWidget] = []

        for widget in widgets {
            if widget.size.columns == 2 {
                if !pending.isEmpty { rows.append(pending); pending = [] }
                rows.append([widget])
            } else {
                pending.append(widget)
                if pending.count == 2 { rows.append(pending); pending = [] }
            }
        }
        if !pending.isEmpty { rows.append(pending) }
        return rows
    }

    private func widgetCard(_ widget: HomeWidget) -> some View {
        NavigationLink { destination(widget.section) } label: {
            widgetBody(widget)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tcCard(padding: widget.size == .large ? 18 : 15)
                .frame(height: widget.size == .large ? 184 : 112)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destination(_ section: HomeSectionID) -> some View {
        switch section {
        case .gym: GymView()
        case .food: FoodShelfView()
        case .calendar: CalendarView()
        case .finance: FinanceView()
        case .wardrobe: WardrobeView()
        case .wishes: WishesView()
        case .projects: ProjectsView()
        case .learning: LearningView()
        case .library: LibraryView()
        }
    }

    /// El id guardado no se usa a pelo: pasa por el catálogo, que devuelve el
    /// primer diseño de la sección si ese id ya no existe.
    @ViewBuilder
    private func widgetBody(_ widget: HomeWidget) -> some View {
        let design = WidgetDesign.named(widget.design, in: widget.section).id
        let big = widget.size == .large

        switch widget.section {
        case .gym:
            switch design {
            case "week": gymWeekBody(big: big)
            case "number": numberBody("Gimnasio",
                                      value: "\(sessionsDone)/\(trainingDays)",
                                      note: "sesiones esta semana")
            default: gymRingBody(big: big)
            }

        case .food:
            switch design {
            case "ring": foodRingBody(big: big)
            case "number": numberBody("Comida",
                                      value: todayKcal.formatted(.number.grouping(.automatic)),
                                      note: "de \(goalKcal) kcal")
            default: foodMeterBody(big: big)
            }

        case .calendar:
            switch design {
            case "list": calendarListBody(big: big)
            case "number": numberBody("Calendario",
                                      value: nextDate.map { shortDate($0.date) } ?? "—",
                                      note: nextDate?.title ?? "sin fechas cerca")
            default: calendarNextBody(big: big)
            }

        case .finance:
            switch design {
            case "split": financeSplitBody(big: big)
            case "number": numberBody("Finanzas",
                                      value: Cents.formatted(totalBalanceCents),
                                      note: "saldo acumulado")
            default: financeRingsBody(big: big)
            }

        default:
            if design == "list" {
                listBody(widget.section, big: big)
            } else {
                numberBody(widget.section.label,
                           value: "\(count(widget.section))",
                           note: countNote(widget.section))
            }
        }
    }

    // MARK: - Caras de widget

    private func numberBody(_ label: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).tcLabel()
            Spacer(minLength: 0)
            Text(value).tcNumber(26).lineLimit(1).minimumScaleFactor(0.55)
            Text(note).tcMicro().lineLimit(1)
        }
    }

    private func gymRingBody(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 15) {
                ZStack {
                    TCRing(value: trainingDays == 0 ? 0 : Double(sessionsDone) / Double(trainingDays))
                    Text("\(sessionsDone)/\(trainingDays)").tcNumber(big ? 17 : 14)
                }
                .frame(width: big ? 76 : 60, height: big ? 76 : 60)

                VStack(alignment: .leading, spacing: 5) {
                    Text("GIMNASIO").tcLabel()
                    Text(todayPlan?.template?.name ?? "Descanso").tcSection().lineLimit(1)
                    Text(gymSubtitle).tcBody().lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            if big {
                Spacer(minLength: 0)
                weekRow
            }
        }
    }

    private func gymWeekBody(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GIMNASIO").tcLabel()
                Spacer()
                Text("\(sessionsDone)/\(trainingDays)").tcNumber(15)
            }
            Spacer(minLength: 0)
            weekRow
            if big {
                Text(gymSubtitle).tcBody().lineLimit(2)
            }
        }
    }

    private var weekRow: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                VStack(spacing: 7) {
                    Text(day.letter)
                        .font(TCFont.font(11))
                        .foregroundStyle(isRest(day) ? TCColor.textFaint : TCColor.textSoft)
                    dayMark(for: day)
                        .frame(height: 7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var gymSubtitle: String {
        guard trainingDays > 0 else { return "Monta tu rutina para empezar" }
        if todayPlan?.isRestDay ?? true { return "Hoy descansas" }
        return "\(sessionsDone) de \(trainingDays) sesiones esta semana"
    }

    private func isRest(_ day: Weekday) -> Bool {
        routine?.day(day)?.isRestDay ?? true
    }

    @ViewBuilder
    private func dayMark(for day: Weekday) -> some View {
        if isRest(day) {
            Capsule().fill(TCColor.track).frame(width: 7, height: 1.5)
        } else {
            Circle()
                .fill(weekdaysTrained.contains(day.rawValue) ? TCColor.moss : TCColor.track)
                .frame(width: 7, height: 7)
        }
    }

    private var kcalShare: Double {
        goalKcal == 0 ? 0 : Double(todayKcal) / Double(goalKcal)
    }

    private func foodMeterBody(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMIDA").tcLabel()
            Spacer(minLength: 0)
            Text(todayKcal.formatted(.number.grouping(.automatic))).tcNumber(big ? 30 : 22)
            Text("de \(goalKcal.formatted(.number.grouping(.automatic))) kcal").tcMicro()
            TCProgressBar(value: kcalShare, height: 4)
            if big {
                Text(kcalNote).tcMicro().padding(.top, 2)
            }
        }
    }

    private var kcalNote: String {
        let left = goalKcal - todayKcal
        if left >= 0 { return "te quedan \(left) kcal" }
        return "\(-left) kcal por encima"
    }

    private func foodRingBody(big: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                TCRing(value: kcalShare, lineWidth: big ? 8 : 5)
                Text("\(Int((kcalShare * 100).rounded()))%").tcNumber(big ? 16 : 12)
            }
            .frame(width: big ? 74 : 52, height: big ? 74 : 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("COMIDA").tcLabel()
                Text(todayKcal.formatted(.number.grouping(.automatic))).tcNumber(big ? 24 : 18)
                Text("de \(goalKcal) kcal").tcMicro().lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func calendarNextBody(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CALENDARIO").tcLabel()
            Spacer(minLength: 0)
            if let next = nextDate {
                Text(shortDate(next.date)).tcNumber(big ? 30 : 22)
                Text(next.title).tcMicro().lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(color(for: next.color)).frame(width: 7, height: 7)
                    Text(daysAway(next.date)).tcMicro()
                }
            } else {
                Text("—").tcNumber(big ? 30 : 22)
                Text("Sin fechas cerca").tcMicro()
            }
        }
    }

    private var upcomingDates: [ImportantDate] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return importantDates.filter { $0.date >= startOfToday }
    }

    private func calendarListBody(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("CALENDARIO").tcLabel()
                Spacer()
                Text("\(upcomingDates.count)").tcMicro()
            }

            if upcomingDates.isEmpty {
                Spacer(minLength: 0)
                Text("Sin fechas cerca").tcMicro()
            } else {
                ForEach(upcomingDates.prefix(big ? 4 : 2)) { date in
                    HStack(spacing: 8) {
                        Circle().fill(color(for: date.color)).frame(width: 6, height: 6)
                        Text(date.title)
                            .font(TCFont.font(12))
                            .foregroundStyle(TCColor.text)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(shortDate(date.date)).tcMicro()
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Finanzas en el inicio

    private var totalBalanceCents: Int {
        wallets.reduce(0) { $0 + $1.balanceCents }
    }

    private func share(_ wallet: Wallet) -> Double {
        let total = wallets.reduce(0) { $0 + max($1.balanceCents, 0) }
        guard total > 0 else { return 0 }
        return Double(max(wallet.balanceCents, 0)) / Double(total)
    }

    private var financeRings: [ConcentricRings.Ring] {
        Array(wallets.prefix(ConcentricRings.maxRings)).enumerated().map { index, wallet in
            ConcentricRings.Ring(id: "\(index)",
                                 value: share(wallet),
                                 color: color(for: wallet.color))
        }
    }

    private func financeRingsBody(big: Bool) -> some View {
        HStack(spacing: 15) {
            ConcentricRings(rings: financeRings, lineWidth: big ? 7 : 5, spacing: 2)
                .frame(width: big ? 94 : 64, height: big ? 94 : 64)

            VStack(alignment: .leading, spacing: 5) {
                Text("FINANZAS").tcLabel()
                Text(Cents.formatted(totalBalanceCents))
                    .tcNumber(big ? 24 : 17)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(wallets.isEmpty ? "sin carteras" : "\(wallets.count) carteras").tcMicro()
            }
            Spacer(minLength: 0)
        }
    }

    private func financeSplitBody(big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FINANZAS").tcLabel()
                Spacer()
                Text(Cents.formatted(totalBalanceCents))
                    .tcNumber(13)
                    .lineLimit(1)
            }

            if wallets.isEmpty {
                Spacer(minLength: 0)
                Text("Sin carteras todavía").tcMicro()
            } else {
                Spacer(minLength: 0)
                ForEach(wallets.prefix(big ? 3 : 2)) { wallet in
                    HStack(spacing: 8) {
                        Text(wallet.name)
                            .font(TCFont.font(11))
                            .foregroundStyle(TCColor.textSoft)
                            .lineLimit(1)
                            .frame(width: 62, alignment: .leading)
                        TCProgressBar(value: share(wallet), tint: color(for: wallet.color), height: 4)
                        Text("\(Int((share(wallet) * 100).rounded()))%")
                            .font(TCFont.font(10))
                            .monospacedDigit()
                            .foregroundStyle(TCColor.textMicro)
                    }
                }
            }
        }
    }

    // MARK: - Las secciones que solo cuentan cosas

    private func count(_ section: HomeSectionID) -> Int {
        switch section {
        case .wardrobe: return garments.count
        case .wishes: return wishItems.count
        case .projects: return projects.count
        case .learning: return courses.count
        case .library: return books.count
        default: return 0
        }
    }

    private func countNote(_ section: HomeSectionID) -> String {
        switch section {
        case .wardrobe: return "prendas guardadas"
        case .wishes: return "caprichos apuntados"
        case .projects: return "proyectos"
        case .learning: return "cursos"
        case .library: return "libros"
        default: return ""
        }
    }

    private func names(_ section: HomeSectionID, limit: Int) -> [String] {
        let all: [String]
        switch section {
        case .wardrobe: all = garments.map(\.name)
        case .wishes: all = wishItems.map(\.name)
        case .projects: all = projects.map(\.name)
        case .learning: all = courses.map(\.name)
        case .library: all = books.map(\.title)
        default: all = []
        }
        return Array(all.prefix(limit))
    }

    private func listBody(_ section: HomeSectionID, big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(section.label.uppercased()).tcLabel()
                Spacer()
                Text("\(count(section))").tcMicro()
            }

            if count(section) == 0 {
                Spacer(minLength: 0)
                Text("Nada apuntado todavía").tcMicro()
            } else {
                // Por posición y no por nombre: dos prendas pueden llamarse igual
                // y un id repetido hace que SwiftUI dibuje una sola.
                ForEach(Array(names(section, limit: big ? 4 : 2).enumerated()), id: \.offset) { _, name in
                    HStack(spacing: 8) {
                        Circle().fill(TCColor.moss).frame(width: 5, height: 5)
                        Text(name)
                            .font(TCFont.font(12))
                            .foregroundStyle(TCColor.text)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func daysAway(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case 0: return "hoy"
        case 1: return "mañana"
        default: return "en \(days) días"
        }
    }

    private func color(for palette: PaletteColor) -> Color {
        switch palette {
        case .moss: return TCColor.moss
        case .blue: return TCColor.blue
        case .sand: return TCColor.sand
        case .clay: return TCColor.clay
        case .lilac: return TCColor.lilac
        case .neutral: return TCColor.textSoft
        }
    }

    // MARK: - Barra de secciones

    /// Lo que no está arriba como widget, está aquí abajo. Nunca las dos cosas:
    /// la galería decide de qué lado cae cada sección.
    private var barSections: [HomeSectionID] {
        let onTop = Set(widgets.map(\.section))
        return HomeSectionID.allCases.filter { !onTop.contains($0) }
    }

    private func symbol(for section: HomeSectionID) -> String {
        switch section {
        case .gym: return "dumbbell"
        case .food: return "fork.knife"
        case .wardrobe: return "hanger"
        case .wishes: return "sparkles"
        case .calendar: return "calendar"
        case .projects: return "flag"
        case .learning: return "lightbulb"
        case .library: return "books.vertical"
        case .finance: return "circle.circle"
        }
    }

    /// Debajo de un icono de 48 pt no caben «Emprendimientos» ni «Alimentación».
    private func shortName(for section: HomeSectionID) -> String {
        switch section {
        case .food: return "Comida"
        case .projects: return "Proyectos"
        default: return section.label
        }
    }

    private var sectionsBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(barSections) { section in
                    NavigationLink { destination(section) } label: { sectionIcon(section) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .scrollIndicators(.hidden)
        .background(TCColor.card)
        .clipShape(RoundedRectangle(cornerRadius: TCRadius.bar, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TCRadius.bar, style: .continuous)
                .stroke(TCColor.line, lineWidth: 1)
        )
    }

    // MARK: - Los cuatro botones

    private struct HomeTab { let name: String; let symbol: String }

    private let tabs: [HomeTab] = [
        .init(name: "Inicio", symbol: "house"),
        .init(name: "Buscar", symbol: "magnifyingglass"),
        .init(name: "Añadir", symbol: "plus.circle"),
        .init(name: "Ajustes", symbol: "slider.horizontal.3")
    ]

    private func sectionIcon(_ section: HomeSectionID) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol(for: section))
                .font(.system(size: 20, weight: .light))
                .frame(height: 23)
                .foregroundStyle(TCColor.text)
            Text(shortName(for: section))
                .font(TCFont.font(10))
                .foregroundStyle(TCColor.textSoft)
                .lineLimit(1)
        }
        .frame(width: 52)
    }

    /// Añadir abre la hoja del movimiento desde cualquier sitio. Es el atajo que
    /// hace creíble lo de apuntar un gasto en tres toques.
    private func tapTab(_ index: Int) {
        if index == 2 { addingMovement = true } else { selectedTab = index }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                if index == 3 {
                    NavigationLink { SettingsView(lock: lock) } label: { tabLabel(index, tab) }
                        .buttonStyle(.plain)
                } else {
                    Button { tapTab(index) } label: { tabLabel(index, tab) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func tabLabel(_ index: Int, _ tab: HomeTab) -> some View {
        VStack(spacing: 6) {
            Image(systemName: tab.symbol)
                .font(.system(size: 20, weight: .light))
            Text(tab.name).font(TCFont.font(10, index == selectedTab ? .medium : .regular))
        }
        .foregroundStyle(index == selectedTab ? TCColor.moss : TCColor.textMicro)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}
