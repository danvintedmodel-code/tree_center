import SwiftData
import SwiftUI
import TreeCenterData

// El centro del árbol: widgets arriba, barra de secciones abajo y los cuatro
// botones pegados al borde. Las cifras salen ya de SwiftData, no del aire.
//
// Los iconos son SF Symbols de momento. El set propio de línea de 1,4 px entra
// cuando esté dibujado; cambiar uno por otro es tocar solo `HomeSection.symbol`.

struct HomeView: View {
    /// Hace falta aquí solo para Ajustes, que es desde donde se cambia el trazo.
    let lock: LockController

    @Query private var routines: [Routine]
    @Query private var workouts: [Workout]
    @Query private var meals: [MealEntry]
    @Query private var goals: [NutritionGoal]
    @Query(sort: \ImportantDate.date) private var importantDates: [ImportantDate]

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
                    NavigationLink { GymView() } label: { gymWidget }
                        .buttonStyle(.plain)
                    HStack(spacing: 12) {
                        NavigationLink { FoodShelfView() } label: { foodWidget }
                            .buttonStyle(.plain)
                        NavigationLink { CalendarView() } label: { calendarWidget }
                            .buttonStyle(.plain)
                    }
                    Button("Añadir widget") {}
                        .buttonStyle(TCGhostButtonStyle(dashed: true))
                        .frame(height: 44)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            sectionsBar
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 14)

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

    private var gymWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    TCRing(value: trainingDays == 0 ? 0 : Double(sessionsDone) / Double(trainingDays))
                    Text("\(sessionsDone)/\(trainingDays)").tcNumber(17)
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 5) {
                    Text("GIMNASIO").tcLabel()
                    Text(todayPlan?.template?.name ?? "Descanso").tcSection()
                    Text(gymSubtitle).tcBody()
                }
                Spacer(minLength: 0)
            }

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
        .tcCard(padding: 18)
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

    private var foodWidget: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("COMIDA").tcLabel()
            Text(todayKcal.formatted(.number.grouping(.automatic))).tcNumber(22)
            Text("de \(goalKcal.formatted(.number.grouping(.automatic))) kcal").tcMicro()
            TCProgressBar(value: goalKcal == 0 ? 0 : Double(todayKcal) / Double(goalKcal), height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard()
    }

    private var calendarWidget: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("CALENDARIO").tcLabel()
            if let next = nextDate {
                Text(shortDate(next.date)).tcNumber(22)
                Text(next.title).tcMicro().lineLimit(1)
                HStack(spacing: 6) {
                    Circle().fill(color(for: next.color)).frame(width: 7, height: 7)
                    Text(daysAway(next.date)).tcMicro()
                }
            } else {
                Text("—").tcNumber(22)
                Text("Sin fechas cerca").tcMicro()
                Text("Añade la primera").tcMicro()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard()
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

    // Nombres propios: `Section` y `Tab` ya existen en SwiftUI y taparlos da sustos.
    private enum SectionGo { case wardrobe, wishes, projects, learning, library, finance }

    private struct HomeSection: Identifiable {
        let id = UUID()
        let name: String
        let symbol: String
        let go: SectionGo
    }

    private let sections: [HomeSection] = [
        .init(name: "Armario", symbol: "hanger", go: .wardrobe),
        .init(name: "Caprichos", symbol: "sparkles", go: .wishes),
        .init(name: "Proyectos", symbol: "flag", go: .projects),
        .init(name: "Formación", symbol: "lightbulb", go: .learning),
        .init(name: "Biblioteca", symbol: "books.vertical", go: .library),
        .init(name: "Finanzas", symbol: "circle.circle", go: .finance)
    ]

    private var sectionsBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(sections) { section in
                    // Armario y Caprichos siguen sin pantalla, así que se quedan
                    // como botones mudos: un enlace que no lleva a ningún sitio
                    // es peor que un botón que no hace nada.
                    switch section.go {
                    case .projects:
                        NavigationLink { ProjectsView() } label: { sectionIcon(section) }
                            .buttonStyle(.plain)
                    case .learning:
                        NavigationLink { LearningView() } label: { sectionIcon(section) }
                            .buttonStyle(.plain)
                    case .library:
                        NavigationLink { LibraryView() } label: { sectionIcon(section) }
                            .buttonStyle(.plain)
                    case .finance:
                        NavigationLink { FinanceView() } label: { sectionIcon(section) }
                            .buttonStyle(.plain)
                    case .wardrobe, .wishes:
                        Button {} label: { sectionIcon(section) }
                            .buttonStyle(.plain)
                    }
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

    private func sectionIcon(_ section: HomeSection) -> some View {
        VStack(spacing: 8) {
            Image(systemName: section.symbol)
                .font(.system(size: 20, weight: .light))
                .frame(height: 23)
                .foregroundStyle(TCColor.text)
            Text(section.name)
                .font(TCFont.font(10))
                .foregroundStyle(TCColor.textSoft)
        }
        .frame(width: 48)
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
