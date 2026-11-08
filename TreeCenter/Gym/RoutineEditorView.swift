import SwiftData
import SwiftUI
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

                VStack(spacing: 0) {
                    ForEach(template.orderedPlan) { planned in
                        HStack(spacing: 11) {
                            Text(planned.exercise?.name ?? "Ejercicio")
                                .font(TCFont.font(13.5))
                                .foregroundStyle(TCColor.text)
                            Spacer(minLength: 8)
                            Text("\(planned.sets) × \(planned.reps)")
                                .font(TCFont.font(12))
                                .monospacedDigit()
                                .foregroundStyle(TCColor.textSoft)
                        }
                        .padding(.vertical, 9)

                        Divider().overlay(TCColor.line)
                    }

                    HStack(spacing: 9) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Añadir ejercicio").font(TCFont.font(12.5))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(TCColor.textMicro)
                    .padding(.vertical, 11)
                }
                .tcCard(padding: 14)
            }
        }
    }
}
