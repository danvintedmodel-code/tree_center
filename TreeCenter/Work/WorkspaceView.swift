import SwiftData
import SwiftUI
import TreeCenterCore
import TreeCenterData

// El espacio de trabajo de un proyecto o un curso: resumen con estadísticas,
// tareas, notas e ideas, y la campana de los avisos.
//
// Es genérico sobre el dueño (Project o Course) para no escribir dos veces lo
// mismo. Lo único que cambia es la tarjeta de lecciones, que solo tiene un curso.

private enum WorkspaceTab: String, CaseIterable, Identifiable {
    case summary, tasks, notes, ideas

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summary: return "Resumen"
        case .tasks: return "Tareas"
        case .notes: return "Notas"
        case .ideas: return "Ideas"
        }
    }
}

/// Una nota que se abre en el editor. Nil = nota nueva.
private struct NoteTarget: Identifiable {
    let id = UUID()
    let note: WorkNote?
}

struct WorkspaceView<Owner: WorkspaceOwner>: View {
    let owner: Owner
    let subtitle: String
    /// Solo en un curso: la tarjeta de lecciones del resumen.
    var course: Course? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var tab: WorkspaceTab = .summary
    @State private var period: ActivityPeriod = .day
    @State private var newTask = ""
    @State private var newIdea = ""
    @State private var editing: NoteTarget?
    @State private var showingReminders = false

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: owner.name, subtitle: subtitle, back: { dismiss() }) {
                Button { showingReminders = true } label: { bell }
                    .accessibilityLabel("Avisos")
            }

            HStack(spacing: 6) {
                ForEach(WorkspaceTab.allCases) { option in
                    Button { tab = option } label: {
                        TCChip(text: option.label, selected: tab == option)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 14) {
                    switch tab {
                    case .summary: summary
                    case .tasks: tasks
                    case .notes: notes
                    case .ideas: ideas
                    }
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { target in
            NoteEditor(owner: owner, note: target.note)
        }
        .sheet(isPresented: $showingReminders) {
            RemindersView(owner: owner)
        }
    }

    private var bell: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(TCColor.text)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
            if !owner.reminders.isEmpty {
                Circle().fill(TCColor.moss).frame(width: 7, height: 7).offset(x: -4, y: 4)
            }
        }
    }

    // MARK: - Resumen

    private var summary: some View {
        let dates = owner.activityDates
        let calendar = Calendar.current
        let chart = chartData(dates, calendar: calendar)
        let done = owner.tasks.filter(\.done).count

        return VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(ActivityPeriod.allCases, id: \.self) { option in
                    Button { period = option } label: {
                        TCChip(text: periodLabel(option), selected: period == option)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            ActivityBars(values: chart.values, labels: chart.labels)
                .frame(height: 110)
                .tcCard(padding: 14)

            HStack(spacing: 8) {
                tile("SEMANA", "\(ActivityStats.thisWeek(dates, now: .now, calendar: calendar))")
                tile("RACHA", "\(ActivityStats.streak(dates, now: .now, calendar: calendar)) d")
                tile("HECHO", owner.tasks.isEmpty ? "—" : "\(Int((Double(done) / Double(owner.tasks.count) * 100).rounded()))%")
            }

            if let course {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("LECCIONES").tcLabel()
                        Spacer()
                        Text("\(course.currentLesson) / \(course.totalLessons)").tcNumber(13)
                    }
                    TCProgressBar(value: course.progress)
                    Button {
                        course.completeLesson()
                        try? context.save()
                    } label: {
                        TCChip(text: course.isFinished ? "Curso terminado" : "+ Lección hecha")
                    }
                    .buttonStyle(.plain)
                    .disabled(course.isFinished)
                }
                .tcCard(padding: 16)
            }

            Text("Cuenta lo que haces: cada tarea cerrada, cada nota y cada lección suman al día en que pasan.")
                .tcMicro()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(TCFont.font(9.5, .semibold))
                .tracking(1)
                .foregroundStyle(TCColor.textMicro)
            Text(value)
                .font(TCFont.font(17, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.text)
        }
        .frame(maxWidth: .infinity)
        .tcCard(padding: 11, radius: TCRadius.control)
    }

    private func periodLabel(_ period: ActivityPeriod) -> String {
        switch period {
        case .day: return "Día"
        case .week: return "Semana"
        case .month: return "Mes"
        }
    }

    /// Catorce días, ocho semanas o seis meses, siempre terminando hoy.
    private func chartData(_ dates: [Date], calendar: Calendar) -> (values: [Int], labels: [String]) {
        switch period {
        case .day:
            let values = ActivityStats.buckets(dates, period: .day, count: 14, now: .now, calendar: calendar)
            let initials = ["D", "L", "M", "X", "J", "V", "S"]
            let labels: [String] = (0..<14).map { k in
                guard let day = calendar.date(byAdding: .day, value: k - 13, to: .now) else { return "" }
                return initials[calendar.component(.weekday, from: day) - 1]
            }
            return (values, labels)

        case .week:
            let values = ActivityStats.buckets(dates, period: .week, count: 8, now: .now, calendar: calendar)
            let labels = (0..<8).map { k in k == 7 ? "esta" : (k % 2 == 1 ? "-\(7 - k)" : "") }
            return (values, labels)

        case .month:
            let values = ActivityStats.buckets(dates, period: .month, count: 6, now: .now, calendar: calendar)
            let f = DateFormatter()
            f.locale = Locale(identifier: "es_ES")
            f.dateFormat = "MMM"
            let labels: [String] = (0..<6).map { k in
                guard let month = calendar.date(byAdding: .month, value: k - 5, to: .now) else { return "" }
                return f.string(from: month).replacingOccurrences(of: ".", with: "")
            }
            return (values, labels)
        }
    }

    // MARK: - Tareas

    private var tasks: some View {
        let ordered = owner.orderedTasks
        let open = ordered.filter { !$0.done }.count

        return VStack(spacing: 14) {
            if ordered.isEmpty {
                Text("Sin tareas todavía.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.element.persistentModelID) { index, task in
                        Button {
                            withAnimation(.easeOut(duration: 0.18)) { task.toggle() }
                            try? context.save()
                        } label: {
                            HStack(spacing: 11) {
                                CheckBox(on: task.done)
                                Text(task.title)
                                    .font(TCFont.font(14))
                                    .foregroundStyle(task.done ? TCColor.textMicro : TCColor.text)
                                    .strikethrough(task.done, color: TCColor.textMicro)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Borrar", role: .destructive) {
                                context.delete(task)
                                try? context.save()
                            }
                        }

                        if index < ordered.count - 1 { Divider().overlay(TCColor.line) }
                    }
                }
                .tcCard(padding: 14)
            }

            HStack(spacing: 8) {
                TextField("Nueva tarea", text: $newTask)
                    .font(TCFont.font(15))
                    .foregroundStyle(TCColor.text)
                    .submitLabel(.done)
                    .onSubmit(addTask)
                    .tcCard(padding: 14, radius: TCRadius.control)
                Button("Añadir", action: addTask)
                    .buttonStyle(TCPrimaryButtonStyle())
                    .frame(width: 96)
                    .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("\(open) pendientes · \(ordered.count - open) hechas")
                .tcMicro()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addTask() {
        let title = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        newTask = ""
        let task = WorkTask(title: title, order: (owner.tasks.map(\.order).max() ?? -1) + 1)
        context.insert(task)
        owner.adopt(task)
        try? context.save()
    }

    // MARK: - Notas

    private var notes: some View {
        VStack(spacing: 14) {
            Button("Nota de hoy") { editing = NoteTarget(note: nil) }
                .buttonStyle(TCPrimaryButtonStyle())

            if owner.notes.isEmpty {
                VStack(spacing: 8) {
                    Text("Sin notas").tcRow()
                    Text("Una nota por día, con títulos, listas y casillas que se marcan con el dedo.")
                        .tcMicro()
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .tcCard(padding: 16, sunken: true)
            }

            ForEach(owner.recentNotes) { note in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(day(note.createdAt).uppercased()).tcLabel()
                        Spacer()
                        Button("Editar") { editing = NoteTarget(note: note) }
                            .font(TCFont.font(12.5))
                            .foregroundStyle(TCColor.moss)
                    }
                    NoteText(text: note.text) { line in
                        note.text = NoteMarkup.toggleCheck(in: note.text, line: line)
                        note.editedAt = .now
                        try? context.save()
                    }
                }
                .tcCard(padding: 16)
                .contextMenu {
                    Button("Borrar", role: .destructive) {
                        context.delete(note)
                        try? context.save()
                    }
                }
            }
        }
    }

    private func day(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "hoy" }
        if Calendar.current.isDateInYesterday(date) { return "ayer" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    // MARK: - Ideas

    private var ideas: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                TextField("Una idea, aunque sea a medias", text: $newIdea, axis: .vertical)
                    .font(TCFont.font(15))
                    .foregroundStyle(TCColor.text)
                    .lineLimit(1...4)
                    .tcCard(padding: 14, radius: TCRadius.control)
                Button("Guardar", action: addIdea)
                    .buttonStyle(TCPrimaryButtonStyle())
                    .frame(width: 96)
                    .disabled(newIdea.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if owner.ideas.isEmpty {
                Text("Nada apuntado.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(owner.recentIdeas) { idea in
                HStack(alignment: .top, spacing: 10) {
                    Text("✦").foregroundStyle(TCColor.sand)
                    Text(idea.text)
                        .font(TCFont.font(13.5))
                        .foregroundStyle(TCColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        context.delete(idea)
                        try? context.save()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(TCColor.textFaint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quitar")
                }
                .tcCard(padding: 14)
            }
        }
    }

    private func addIdea() {
        let text = newIdea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newIdea = ""
        let idea = WorkIdea(text: text)
        context.insert(idea)
        owner.adopt(idea)
        try? context.save()
    }
}

// MARK: - La gráfica

/// Barras sencillas, la de hoy en musgo lleno y las demás a media tinta. Swift
/// Charts sería más corto, pero así se controla cada píxel del dibujo.
struct ActivityBars: View {
    let values: [Int]
    let labels: [String]

    var body: some View {
        let maximum = max(values.max() ?? 0, 1)

        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 5) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(TCColor.moss.opacity(index == values.count - 1 ? 1 : (value == 0 ? 0.15 : 0.45)))
                        .frame(height: max(3, CGFloat(value) / CGFloat(maximum) * 72))
                    Text(index < labels.count ? labels[index] : "")
                        .font(TCFont.font(8.5))
                        .foregroundStyle(TCColor.textMicro)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(height: 11)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Actividad: \(values.reduce(0, +)) en el periodo")
    }
}

// MARK: - La tarjeta de la lista

struct WorkspaceCard<Owner: WorkspaceOwner>: View {
    let owner: Owner
    let status: String
    let progress: Double

    var body: some View {
        let dates = owner.activityDates
        let calendar = Calendar.current

        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Text(owner.name).tcSection()
                Spacer(minLength: 8)
                Text(status)
                    .font(TCFont.font(11))
                    .foregroundStyle(TCColor.textMicro)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(TCColor.line, lineWidth: 1))
            }
            TCProgressBar(value: progress)
            HStack(spacing: 14) {
                Text("\(ActivityStats.thisWeek(dates, now: .now, calendar: calendar)) esta semana")
                Text("racha de \(ActivityStats.streak(dates, now: .now, calendar: calendar)) días")
                if !owner.reminders.isEmpty {
                    Text("\(owner.reminders.count) aviso\(owner.reminders.count == 1 ? "" : "s")")
                }
            }
            .font(TCFont.font(11))
            .foregroundStyle(TCColor.textMicro)
        }
        .tcCard(padding: 16)
    }
}
