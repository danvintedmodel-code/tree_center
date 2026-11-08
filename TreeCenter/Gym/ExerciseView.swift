import SwiftData
import SwiftUI
import TreeCenterData

// Ficha de ejercicio. Aquí es donde se apuntan las series mientras entrenas,
// así que lo que manda es que marcar una serie cueste un toque y nada más.
//
// El hueco de la animación es un hueco de verdad: la personita en bucle llega
// cuando entre Lottie. Poner un dibujo aproximado mientras tanto solo serviría
// para que nadie se acuerde de encargar el bueno.

struct ExerciseView: View {
    let planned: PlannedExercise
    let workout: Workout?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var restEndsAt: Date?
    @State private var now = Date.now

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Lo que descansas entre series. Fijo de momento; será ajustable por
    /// ejercicio cuando haya con qué ajustarlo.
    private let restSeconds = 120

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: exercise?.name ?? "Ejercicio",
                           subtitle: recordLine,
                           back: { dismiss() }) { BodytoneMark() }

            ScrollView {
                VStack(spacing: 18) {
                    animationCard
                    viewChips
                    setsSection
                    if restEndsAt != nil { restCard }
                    techniqueCard
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(tick) { value in
            now = value
            if let end = restEndsAt, end <= value { restEndsAt = nil }
        }
    }

    // MARK: - Datos

    private var exercise: Exercise? { planned.exercise }

    private var entries: [SetEntry] {
        guard let workout, let exercise else { return [] }
        return workout.sets
            .filter { $0.exercise?.persistentModelID == exercise.persistentModelID }
            .sorted { $0.index < $1.index }
    }

    private var recordLine: String? {
        guard let exercise else { return nil }
        let logged = exercise.sets.filter { $0.done }
        guard let best = logged.compactMap(\.weight).max() else { return nil }
        return "tu máximo: \(best.formatted(.number.precision(.fractionLength(0...1)))) kg · \(logged.count) series"
    }

    // MARK: - La animación

    private var animationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BUCLE · 2 s POR REP").tcLabel()
            Spacer(minLength: 0)
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 46, weight: .ultraLight))
                        .foregroundStyle(TCColor.textFaint)
                    Text("La animación va aquí")
                        .font(TCFont.font(12))
                        .foregroundStyle(TCColor.textMicro)
                }
                Spacer()
            }
            Spacer(minLength: 0)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard(padding: 16, sunken: true)
    }

    private var viewChips: some View {
        HStack(spacing: 7) {
            TCChip(text: "Lento")
            TCChip(text: "Normal", selected: true)
            TCChip(text: "Lateral")
            TCChip(text: "Frontal")
        }
    }

    // MARK: - Series

    @ViewBuilder
    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Series de hoy", trailing: planned.summary)

            if entries.isEmpty {
                VStack(spacing: 6) {
                    Text("El entreno no ha empezado").tcRow()
                    Text("Vuelve atrás y dale a Empezar entreno para poder apuntar.")
                        .tcMicro()
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                        setRow(entry, isNext: entry.persistentModelID == nextEntry?.persistentModelID)
                        if index < entries.count - 1 {
                            Divider().overlay(TCColor.line)
                        }
                    }
                }
                .tcCard(padding: 14)
            }
        }
    }

    private var nextEntry: SetEntry? { entries.first { !$0.done } }

    private func setRow(_ entry: SetEntry, isNext: Bool) -> some View {
        Button {
            complete(entry)
        } label: {
            HStack(spacing: 12) {
                Text("\(entry.index)")
                    .font(TCFont.font(11))
                    .monospacedDigit()
                    .foregroundStyle(isNext ? TCColor.moss : TCColor.textMicro)
                    .frame(width: 16, alignment: .leading)

                Text(line(for: entry))
                    .font(TCFont.font(isNext ? 15 : 14, isNext ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(entry.done ? TCColor.textSoft : TCColor.text)

                Spacer(minLength: 8)

                if entry.done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TCColor.moss)
                } else if isNext {
                    Text("AHORA")
                        .font(TCFont.font(10, .semibold))
                        .tracking(1)
                        .foregroundStyle(TCColor.moss)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .overlay(Capsule().stroke(TCColor.moss, lineWidth: 1))
                } else {
                    Text("—").tcMicro()
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(entry.done)
    }

    private func line(for entry: SetEntry) -> String {
        let weight = entry.weight.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) kg" }
            ?? "peso corporal"
        return "\(weight) × \(entry.reps)"
    }

    private func complete(_ entry: SetEntry) {
        entry.done = true
        entry.doneAt = .now
        try? context.save()

        // Si quedan series, el descanso arranca solo: es lo que uno quiere
        // justo después de soltar la barra.
        if nextEntry != nil {
            restEndsAt = Date().addingTimeInterval(TimeInterval(restSeconds))
        }
    }

    // MARK: - Descanso

    private var restCard: some View {
        let remaining = max(0, Int((restEndsAt?.timeIntervalSince(now) ?? 0).rounded(.up)))
        let progress = 1 - Double(remaining) / Double(restSeconds)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Descanso").tcBody()
                Spacer()
                Text(clock(remaining))
                    .font(TCFont.font(18, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(TCColor.text)
            }
            TCProgressBar(value: progress, height: 4)
            Button("Saltar descanso") { restEndsAt = nil }
                .font(TCFont.font(12))
                .foregroundStyle(TCColor.textMicro)
        }
        .padding(16)
        .background(TCColor.mossWell)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TCColor.moss, lineWidth: 1)
        )
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Técnica

    @ViewBuilder
    private var techniqueCard: some View {
        let notes = exercise?.technique ?? []

        VStack(alignment: .leading, spacing: 9) {
            Text("TÉCNICA").tcLabel()
            if notes.isEmpty {
                Text("Todavía no has apuntado nada aquí. Tres líneas bastan: lo que se te olvida cuando vas cansado.")
                    .font(TCFont.font(12.5))
                    .foregroundStyle(TCColor.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(TCFont.font(12.5))
                        .foregroundStyle(TCColor.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard(padding: 16)
    }
}
