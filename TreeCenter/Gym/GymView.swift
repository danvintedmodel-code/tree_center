import Charts
import SwiftData
import SwiftUI
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
    /// "4 × 8 · 60 kg", o sin el peso cuando va a peso corporal.
    var summary: String {
        let base = "\(sets) × \(reps)"
        guard let weight else { return base + " · peso corporal" }
        return base + " · \(weight.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }
}
