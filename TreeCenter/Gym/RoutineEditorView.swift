import SwiftData
import SwiftUI
import TreeCenterCore
import TreeCenterData

// Editor de la rutina.
//
// La regla no se comprueba aquí: vive en el modelo (`Weekday.canBeRestDay` y
// `RoutineDay.makeRestDay()`). Esta pantalla se limita a no ofrecer lo que el
// modelo va a rechazar, que es distinto de impedirlo: si mañana hay otra forma
// de editar la rutina, la regla sigue valiendo igual.

struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var routines: [Routine]
    @Query(sort: \WorkoutTemplate.order) private var templates: [WorkoutTemplate]

    @State private var selected: Weekday = .today
    @State private var addingTo: WorkoutTemplate?
    @State private var newExercise = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Rutina", back: { dismiss() })

            ScrollView {
                VStack(spacing: 20) {
                    daysCard
                    ruleNote
                    assignmentCard
                    selectedDayCard
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Añadir ejercicio", isPresented: Binding(get: { addingTo != nil },
                                                        set: { if !$0 { addingTo = nil } })) {
            TextField("Remo en polea", text: $newExercise)
            Button("Cancelar", role: .cancel) { newExercise = ""; addingTo = nil }
            Button("Añadir") {
                if let template = addingTo { addExercise(named: newExercise, to: template) }
                newExercise = ""
                addingTo = nil
            }
        } message: {
            Text("Empieza en 3 × 8–12 con 20 kg. Se ajusta justo debajo.")
        }
    }

    private var routine: Routine? { routines.first }

    // MARK: - Los días

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Días · toca para quitar o poner")

            HStack(spacing: 6) {
                ForEach(Weekday.allCases) { day in
                    dayToggle(day)
                }
            }
            .tcCard(padding: 14)
        }
    }

    private func dayToggle(_ day: Weekday) -> some View {
        let plan = routine?.day(day)
        let rest = plan?.isRestDay ?? true

        return Button {
            toggle(day)
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(rest ? TCColor.cardSunken : TCColor.mossWell)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            rest ? TCColor.lineStrong : TCColor.moss,
                            style: StrokeStyle(lineWidth: rest ? 1 : 1.5,
                                               dash: rest ? [4, 3] : [])
                        )
                    Text(day.letter)
                        .font(TCFont.font(13, .semibold))
                        .foregroundStyle(rest ? TCColor.textFaint : TCColor.moss)
                }
                .frame(height: 44)

                Text(day.canBeRestDay ? (rest ? "libre" : "quitable") : "fijo")
                    .font(TCFont.font(9))
                    .foregroundStyle(day.canBeRestDay ? TCColor.textSoft : TCColor.textFaint)
            }
        }
        .buttonStyle(.plain)
        .disabled(!day.canBeRestDay)
        .accessibilityLabel("\(day.name): \(rest ? "descanso" : "entreno")")
    }

    /// Quitar lo decide el modelo. Poner es siempre válido: se le devuelve la
    /// sesión que más se repite en la semana, que es la suposición menos mala.
    private func toggle(_ day: Weekday) {
        guard let plan = routine?.day(day) else { return }

        if plan.isRestDay {
            plan.template = mostUsedTemplate ?? templates.first
        } else {
            _ = plan.makeRestDay()
        }
        try? context.save()
    }

    private var mostUsedTemplate: WorkoutTemplate? {
        guard let routine else { return nil }
        let counts = Dictionary(grouping: routine.days.compactMap(\.template)) {
            $0.persistentModelID
        }
        return counts.values.max { $0.count < $1.count }?.first
    }

    private var ruleNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(TCColor.clay)
            Text("Solo sábado y domingo se pueden quitar, y como mucho los dos. De lunes a viernes no se tocan.")
                .font(TCFont.font(12.5))
                .foregroundStyle(TCColor.clay)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(TCColor.cardSunken)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TCColor.clay.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Qué toca cada día

    private var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Qué toca cada día")

            VStack(spacing: 0) {
                ForEach(Array(Weekday.allCases.enumerated()), id: \.element) { index, day in
                    assignmentRow(day)
                    if index < Weekday.allCases.count - 1 {
                        Divider().overlay(TCColor.line)
                    }
                }
            }
            .tcCard(padding: 14)
        }
    }

    private func assignmentRow(_ day: Weekday) -> some View {
        let plan = routine?.day(day)
        let rest = plan?.isRestDay ?? true

        return HStack {
            Text(day.name)
                .font(TCFont.font(13.5))
                .foregroundStyle(rest ? TCColor.textFaint : TCColor.text)

            Spacer(minLength: 8)

            if rest {
                Text("Descanso").tcMicro()
            } else {
                Menu {
                    ForEach(templates) { option in
                        Button(option.name) {
                            plan?.template = option
                            try? context.save()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(plan?.template?.name ?? "—")
                            .font(TCFont.font(13))
                            .foregroundStyle(day == selected ? TCColor.moss : TCColor.textSoft)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(TCColor.textFaint)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { if !rest { selected = day } }
    }

    // MARK: - El día elegido

    @ViewBuilder
    private var selectedDayCard: some View {
        if let template = routine?.day(selected)?.template {
            VStack(alignment: .leading, spacing: 10) {
                TCSectionLabel(text: "\(selected.name) · \(template.name)",
                               trailing: "\(template.plan.count)")

                if usage(of: template) > 1 {
                    Text("\(template.name) la usan \(usage(of: template)) días: cambiar un ejercicio aquí lo cambia en todos.")
                        .tcMicro()
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(template.orderedPlan) { planned in
                    PlannedEditor(planned: planned)
                        .contextMenu {
                            Button("Quitar de \(template.name)", role: .destructive) {
                                context.delete(planned)
                                try? context.save()
                            }
                        }
                }

                Button {
                    addingTo = template
                } label: {
                    Label("Añadir ejercicio", systemImage: "plus")
                }
                .buttonStyle(TCGhostButtonStyle(dashed: true))
            }
        }
    }

    private func usage(of template: WorkoutTemplate) -> Int {
        routine?.days.filter { $0.template?.persistentModelID == template.persistentModelID }.count ?? 0
    }

    /// Reutiliza el ejercicio si ya existe con ese nombre: así su historial y su
    /// gráfica siguen siendo uno solo aunque esté en dos sesiones.
    private func addExercise(named raw: String, to template: WorkoutTemplate) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<Exercise>()))?
            .first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        let exercise = existing ?? Exercise(name: name)
        if existing == nil { context.insert(exercise) }

        let planned = PlannedExercise(exercise: exercise,
                                      order: (template.plan.map(\.order).max() ?? -1) + 1,
                                      sets: 3, reps: 12, repsLow: 8, weight: 20)
        context.insert(planned)
        planned.template = template
        try? context.save()
    }
}

/// Un ejercicio de la sesión, con sus tres ajustes: series, rango de
/// repeticiones y peso de trabajo.
private struct PlannedEditor: View {
    @Bindable var planned: PlannedExercise

    @Environment(\.modelContext) private var context

    var body: some View {
        let step = Progression.step(forExerciseNamed: planned.exercise?.name ?? "")

        VStack(alignment: .leading, spacing: 10) {
            Text(planned.exercise?.name ?? "Ejercicio")
                .font(TCFont.font(14, .medium))
                .foregroundStyle(TCColor.text)

            HStack(spacing: 8) {
                tuner("SERIES", "\(planned.sets)",
                      minus: { planned.sets = max(1, planned.sets - 1) },
                      plus: { planned.sets = min(8, planned.sets + 1) })
                tuner("REPS", "\(planned.repsLow)–\(planned.reps)",
                      minus: {
                          planned.repsLow = max(1, planned.repsLow - 1)
                          planned.reps = max(planned.repsLow, planned.reps - 1)
                      },
                      plus: {
                          planned.reps += 1
                          planned.repsLow = min(planned.reps, planned.repsLow + 1)
                      })
                tuner("PESO", planned.weight.map(GymStats.kilos) ?? "corporal",
                      minus: { planned.weight = max(0, (planned.weight ?? 0) - step) },
                      plus: { planned.weight = (planned.weight ?? 0) + step })
            }

            if let notes = planned.exercise?.notes, !notes.isEmpty {
                Text(notes)
                    .font(TCFont.font(11.5))
                    .foregroundStyle(TCColor.textMicro)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tcCard(padding: 14)
    }

    private func tuner(_ label: String, _ value: String,
                       minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(TCFont.font(8.5, .semibold))
                .tracking(1)
                .foregroundStyle(TCColor.textMicro)
            Text(value)
                .font(TCFont.font(13, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                round("−", minus)
                round("+", plus)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(TCColor.well)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func round(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button {
            action()
            try? context.save()
        } label: {
            Text(symbol)
                .font(TCFont.font(13, .medium))
                .foregroundStyle(TCColor.textSoft)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
