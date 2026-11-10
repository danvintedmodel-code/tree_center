import Charts
import SwiftData
import SwiftUI
import TreeCenterCore
import TreeCenterData

// Gimnasio. La semana por delante de todo, luego lo de hoy, y la progresión
// abajo. El botón de empezar crea el entreno con sus series a partir del plan:
// a partir de ahí lo que se apunta es lo que de verdad haces, no lo previsto.

struct GymView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var routines: [Routine]
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var metric: ProgressMetric = .topWeight

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Gimnasio", back: { dismiss() }) { BodytoneMark() }

            ScrollView {
                VStack(spacing: 20) {
                    weekCard
                    todaySection
                    performanceSection
                    progressSection
                    bottomButtons
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Datos

    private var routine: Routine? { routines.first }
    private var todayPlan: RoutineDay? { routine?.day(.today) }
    private var template: WorkoutTemplate? { todayPlan?.template }

    private var openWorkout: Workout? {
        workouts.first { !$0.finished && Calendar.current.isDateInToday($0.date) }
    }

    private var week: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)
            ?? DateInterval(start: .now, duration: 0)
    }

    private var weekdaysTrained: Set<Int> {
        Set(workouts
            .filter { $0.finished && week.contains($0.date) }
            .map { Weekday.from(calendarWeekday: Calendar.current.component(.weekday, from: $0.date)).rawValue })
    }

    private var trainingDays: Int { routine?.days.filter { !$0.isRestDay }.count ?? 0 }

    // MARK: - Rendimiento semanal

    private var performanceSection: some View {
        let volume = GymStats.weeklyVolume(workouts.filter(\.finished))
        let last = volume.count >= 2 ? volume[volume.count - 2] : 0
        let previous = volume.count >= 3 ? volume[volume.count - 3] : 0
        let change: Int? = previous > 0 ? Int(((last - previous) / previous * 100).rounded()) : nil
        let watch = stalled

        return VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Rendimiento semanal", trailing: "kilos movidos")

            ActivityBars(values: volume.map { Int($0.rounded()) },
                         labels: ["hace 3", "hace 2", "pasada", "esta"])
                .frame(height: 110)
                .tcCard(padding: 14)

            Text(performanceLine(last: last, change: change, current: volume.last ?? 0))
                .tcMicro()
                .fixedSize(horizontal: false, vertical: true)

            if !watch.isEmpty {
                TCSectionLabel(text: "Lo que conviene tocar")
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(Array(watch.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            ExerciseView(planned: item.planned, workout: openWorkout)
                        } label: {
                            stallRow(item)
                        }
                        .buttonStyle(.plain)

                        if index < watch.count - 1 { Divider().overlay(TCColor.line) }
                    }
                }
                .tcCard(padding: 14)
            }
        }
    }

    private func performanceLine(last: Double, change: Int?, current: Double) -> String {
        guard last > 0 || current > 0 else {
            return "Cuando termines entrenos, aquí verás si vas subiendo, igualando o bajando."
        }
        var parts: [String] = []
        if last > 0 {
            var sentence = "La semana pasada moviste \(Int(last).formatted()) kg"
            if let change {
                sentence += ", un \(abs(change)) % \(change >= 0 ? "más" : "menos") que la anterior"
            }
            parts.append(sentence + ".")
        }
        parts.append("Esta vas por \(Int(current).formatted()) kg.")
        return parts.joined(separator: " ")
    }

    /// Un ejercicio que no sube: con su tendencia y lo que toca.
    private struct Stall: Identifiable {
        let id: PersistentIdentifier
        let planned: PlannedExercise
        let trend: Trend
        let flatWeeks: Int
        let advice: String
    }

    /// Los ejercicios de la rutina cuyo máximo no ha subido en las últimas
    /// semanas, los más estancados primero. Hacen falta dos semanas con datos
    /// para hablar de tendencia.
    private var stalled: [Stall] {
        guard let routine else { return [] }
        var seen = Set<PersistentIdentifier>()
        var result: [Stall] = []

        for day in routine.orderedDays {
            for planned in day.template?.orderedPlan ?? [] {
                guard let exercise = planned.exercise, !seen.contains(exercise.persistentModelID) else { continue }
                seen.insert(exercise.persistentModelID)

                let tops = GymStats.weeklyTops(of: exercise)
                guard tops.count >= 2 else { continue }
                let trend = Trend.of(weeklyTops: tops)
                guard trend != .up else { continue }

                let advice = GymStats.adviceText(
                    for: planned,
                    lastReps: GymStats.lastReps(of: exercise, excluding: openWorkout)
                ).text
                result.append(Stall(id: exercise.persistentModelID, planned: planned, trend: trend,
                                    flatWeeks: Trend.flatWeeks(weeklyTops: tops), advice: advice))
            }
        }
        return result.sorted { $0.flatWeeks > $1.flatWeeks }
    }

    private func stallRow(_ item: Stall) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.planned.exercise?.name ?? "Ejercicio")
                        .font(TCFont.font(14))
                        .foregroundStyle(TCColor.text)
                    Text(item.trend == .down ? "↓ bajando" : "= estancado")
                        .font(TCFont.font(11, .semibold))
                        .foregroundStyle(item.trend == .down ? TCColor.clay : TCColor.sand)
                }
                Text((item.flatWeeks >= 2 ? "\(item.flatWeeks) semanas sin moverse. " : "") + item.advice)
                    .font(TCFont.font(11.5))
                    .foregroundStyle(TCColor.textMicro)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TCColor.textFaint)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: - La semana

    private var weekCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Weekday.allCases) { day in
                    dayCell(day)
                }
            }
            Text(weekFootnote)
                .tcMicro()
                .multilineTextAlignment(.center)
        }
        .tcCard(padding: 16)
    }

    private func dayCell(_ day: Weekday) -> some View {
        let plan = routine?.day(day)
        let isToday = day == .today
        let rest = plan?.isRestDay ?? true

        return VStack(spacing: 8) {
            Text(day.letter)
                .font(TCFont.font(11))
                .foregroundStyle(rest ? TCColor.textFaint : TCColor.textSoft)

            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(rest ? TCColor.cardSunken : Color.clear)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isToday && !rest ? TCColor.moss : TCColor.line,
                            lineWidth: isToday && !rest ? 1.5 : 1)

                if rest {
                    Capsule().fill(TCColor.track).frame(width: 8, height: 1.5)
                } else {
                    Text(initial(of: plan?.template?.name))
                        .font(TCFont.font(12, isToday ? .semibold : .medium))
                        .foregroundStyle(isToday ? TCColor.moss : TCColor.textSoft)
                }

                if weekdaysTrained.contains(day.rawValue) {
                    VStack {
                        Spacer()
                        Circle().fill(TCColor.moss).frame(width: 5, height: 5).padding(.bottom, 5)
                    }
                }
            }
            .frame(height: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private func initial(of name: String?) -> String {
        guard let first = name?.first else { return "·" }
        return String(first).uppercased()
    }

    private var weekFootnote: String {
        guard let routine, trainingDays > 0 else { return "Aún no has montado la rutina" }
        let names = Set(routine.days.compactMap(\.template?.name)).sorted().joined(separator: " · ")
        let rest = routine.restDays.map { $0.weekday.name.lowercased() }
        guard !rest.isEmpty else { return names }
        return "\(names) — \(rest.joined(separator: " y ")), descanso"
    }

    // MARK: - Hoy

    @ViewBuilder
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: template.map { "Hoy · \($0.name)" } ?? "Hoy",
                           trailing: template.map { "\($0.plan.count) ejercicios" })

            if let template {
                VStack(spacing: 0) {
                    ForEach(Array(template.orderedPlan.enumerated()), id: \.element.persistentModelID) { index, planned in
                        NavigationLink {
                            ExerciseView(planned: planned, workout: openWorkout)
                        } label: {
                            exerciseRow(planned)
                        }
                        .buttonStyle(.plain)

                        if index < template.orderedPlan.count - 1 {
                            Divider().overlay(TCColor.line)
                        }
                    }
                }
                .tcCard(padding: 14)

                if let open = openWorkout {
                    Button("Terminar entreno") { finish(open) }
                        .buttonStyle(TCPrimaryButtonStyle())
                    Text("\(open.sets.filter(\.done).count) de \(open.sets.count) series hechas")
                        .tcMicro()
                        .frame(maxWidth: .infinity)
                } else {
                    Button("Empezar entreno") { startWorkout() }
                        .buttonStyle(TCPrimaryButtonStyle())
                }
            } else {
                VStack(spacing: 8) {
                    Text("Hoy descansas").tcRow()
                    Text("Sábado y domingo son los únicos días que se pueden dejar libres.")
                        .tcMicro()
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .tcCard(padding: 22, sunken: true)
            }
        }
    }

    private func exerciseRow(_ planned: PlannedExercise) -> some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(TCColor.well)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(TCColor.textSoft)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(planned.exercise?.name ?? "Ejercicio").tcRow()
                Text(planned.summary).tcMicro()
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TCColor.textFaint)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func startWorkout() {
        guard let template else { return }

        let workout = Workout(templateName: template.name)
        context.insert(workout)

        for planned in template.orderedPlan {
            for index in 1...max(1, planned.sets) {
                let entry = SetEntry(index: index, weight: planned.weight,
                                     reps: planned.reps, exercise: planned.exercise)
                context.insert(entry)
                entry.workout = workout
            }
        }
        try? context.save()
    }

    /// Terminar es lo que mete el entreno en el historial: hasta que no se marca,
    /// la progresión no lo cuenta. Si no, media gráfica serían entrenos a medias.
    private func finish(_ workout: Workout) {
        workout.finished = true
        workout.durationMinutes = max(1, Int(Date().timeIntervalSince(workout.date) / 60))
        try? context.save()
    }

    // MARK: - Progresión

    private struct Point: Identifiable {
        let id = UUID()
        let week: Date
        let value: Double
    }

    private var chartExercise: Exercise? { template?.orderedPlan.first?.exercise }

    private var points: [Point] {
        guard let chartExercise else { return [] }

        let logged = chartExercise.sets.filter { $0.done && ($0.workout?.finished ?? false) }
        let byWeek = Dictionary(grouping: logged) { entry -> Date in
            let date = entry.workout?.date ?? Date()
            return Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        }

        return byWeek
            .map { Point(week: $0.key, value: value(of: $0.value)) }
            .sorted { $0.week < $1.week }
    }

    private func value(of sets: [SetEntry]) -> Double {
        switch metric {
        case .topWeight: return sets.compactMap(\.weight).max() ?? 0
        case .volume: return sets.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps) }
        case .reps: return Double(sets.reduce(0) { $0 + $1.reps })
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Progresión", trailing: chartExercise?.name)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    ForEach(ProgressMetric.allCases) { option in
                        Button { metric = option } label: {
                            TCChip(text: option.label, selected: option == metric)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if points.count >= 2 {
                    Chart(points) { point in
                        LineMark(x: .value("Semana", point.week),
                                 y: .value(metric.label, point.value))
                            .foregroundStyle(TCColor.moss)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.monotone)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .trailing) { _ in
                            AxisGridLine().foregroundStyle(TCColor.line)
                            AxisValueLabel().foregroundStyle(TCColor.textMicro)
                        }
                    }
                    .frame(height: 96)

                    if let first = points.first, let last = points.last {
                        HStack {
                            Text("\(points.count) semanas").tcMicro()
                            Spacer()
                            Text("\(number(first.value)) → \(number(last.value))")
                                .font(TCFont.font(13, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(TCColor.text)
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        Text("Aún no hay historial").tcRow()
                        Text("Hacen falta dos semanas de entrenos apuntados para que esto diga algo.")
                            .tcMicro()
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
            }
            .tcCard(padding: 16)
        }
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    // MARK: - Pie

    private var bottomButtons: some View {
        HStack(spacing: 10) {
            NavigationLink {
                RoutineEditorView()
            } label: {
                Text("Editar rutina")
                    .font(TCFont.font(14, .medium))
                    .foregroundStyle(TCColor.text)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(TCColor.lineStrong, lineWidth: 1)
                    )
            }

            Button("Medidas") {}
                .buttonStyle(TCGhostButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }
}

extension PlannedExercise {
    /// "4 × 6–8 · 60 kg", o sin el peso cuando va a peso corporal.
    var summary: String {
        let base = repsLow < reps ? "\(sets) × \(repsLow)–\(reps)" : "\(sets) × \(reps)"
        guard let weight else { return base + " · peso corporal" }
        return base + " · \(weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}
