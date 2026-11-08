import SwiftData
import SwiftUI
import TreeCenterData

// Calendario. Fechas que importan, no una agenda de reuniones: vive aparte del
// calendario del iPhone a propósito.

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \ImportantDate.date) private var dates: [ImportantDate]

    @State private var month = Calendar.current.monthInterval().start
    @State private var filter: DateKind?
    @State private var adding = false

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Calendario", back: { dismiss() }) {
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Nueva fecha")
            }

            ScrollView {
                VStack(spacing: 18) {
                    monthHeader
                    grid
                    kindChips
                    upcoming
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) { ImportantDateEditor() }
    }

    // MARK: - Mes

    private var monthHeader: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(TCFont.font(17, .semibold))
                .foregroundStyle(TCColor.text)
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
            }
        }
        .foregroundStyle(TCColor.textSoft)
        .buttonStyle(.plain)
    }

    private func shift(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.easeOut(duration: 0.18)) { month = next }
    }

    /// Celdas del mes, con huecos delante para que el 1 caiga en su día.
    /// La semana empieza en lunes: la conversión está en `Weekday.from`.
    private var cells: [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }

        let firstWeekday = Weekday.from(calendarWeekday: cal.component(.weekday, from: month)).rawValue
        let leading = Array(repeating: Date?.none, count: firstWeekday - 1)
        let days = range.compactMap { day in cal.date(byAdding: .day, value: day - 1, to: month) }
        return leading + days.map { Optional($0) }
    }

    private var grid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Weekday.allCases) { day in
                    Text(day.letter)
                        .font(TCFont.font(10, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(day.canBeRestDay ? TCColor.textFaint : TCColor.textMicro)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    dayCell(day)
                }
            }
        }
        .tcCard(padding: 14)
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isToday = Calendar.current.isDateInToday(day)
            let marks = kinds(on: day)

            VStack(spacing: 3) {
                Text(Calendar.current.component(.day, from: day).formatted())
                    .font(TCFont.font(14, isToday ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? TCColor.onMoss : TCColor.text)
                    .frame(width: 28, height: 28)
                    .background(isToday ? TCColor.moss : Color.clear)
                    .clipShape(Circle())

                HStack(spacing: 3) {
                    ForEach(Array(marks.prefix(3).enumerated()), id: \.offset) { _, kind in
                        Circle().fill(color(kind)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 40)
        } else {
            Color.clear.frame(height: 40)
        }
    }

    private func kinds(on day: Date) -> [DateKind] {
        shown
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .map(\.kind)
    }

    private func color(_ kind: DateKind) -> Color {
        switch kind {
        case .birthday: return TCColor.blue
        case .payment: return TCColor.sand
        case .delivery: return TCColor.clay
        case .review: return TCColor.lilac
        }
    }

    // MARK: - Filtro

    private var shown: [ImportantDate] {
        guard let filter else { return dates }
        return dates.filter { $0.kind == filter }
    }

    private var kindChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(DateKind.allCases) { kind in
                    Button { filter = filter == kind ? nil : kind } label: {
                        HStack(spacing: 6) {
                            Circle().fill(color(kind)).frame(width: 7, height: 7)
                            Text(kind.label)
                                .font(TCFont.font(11))
                                .foregroundStyle(filter == kind ? TCColor.text : TCColor.textSoft)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule().stroke(filter == kind ? TCColor.text : TCColor.line, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Próximas

    private var upcoming: some View {
        let start = Calendar.current.startOfDay(for: .now)
        let next = shown.filter { $0.date >= start }.prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Próximas")

            if next.isEmpty {
                Text("Nada en el horizonte.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(next.enumerated()), id: \.element.persistentModelID) { index, item in
                        HStack(spacing: 12) {
                            Circle().fill(color(item.kind)).frame(width: 7, height: 7)
                            Text(item.title).font(TCFont.font(13.5)).foregroundStyle(TCColor.text)
                            Spacer(minLength: 8)
                            Text(item.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(TCFont.font(12.5))
                                .monospacedDigit()
                                .foregroundStyle(TCColor.textSoft)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        // Fuera de una List no hay swipe: el menú contextual es
                        // la forma que sí funciona en una pila normal.
                        .contextMenu {
                            Button("Borrar", role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            }
                        }

                        if index < next.count - 1 { Divider().overlay(TCColor.line) }
                    }
                }
                .tcCard(padding: 14)
            }
        }
    }
}

// MARK: - Nueva fecha

private struct ImportantDateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var date = Date()
    @State private var kind: DateKind = .payment
    @State private var repeats = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .font(TCFont.font(14)).foregroundStyle(TCColor.textSoft)
                Spacer()
                Text("Nueva fecha").font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
                Spacer()
                Button("Guardar") { save() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(canSave ? TCColor.moss : TCColor.textFaint)
                    .disabled(!canSave)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 16)
            .background(TCColor.cardSunken)

            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Qué es")
                        TextField("Renovar dominio", text: $title)
                            .font(TCFont.font(15))
                            .foregroundStyle(TCColor.text)
                            .tcCard(padding: 14, radius: TCRadius.control)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Cuándo")
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                            .tint(TCColor.moss)
                            .tcCard(padding: 8, radius: TCRadius.card)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Tipo")
                        ScrollView(.horizontal) {
                            HStack(spacing: 7) {
                                ForEach(DateKind.allCases) { option in
                                    Button { kind = option } label: {
                                        TCChip(text: option.label, selected: option == kind)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    Toggle("Se repite cada año", isOn: $repeats)
                        .font(TCFont.font(14))
                        .foregroundStyle(TCColor.text)
                        .tint(TCColor.moss)
                        .tcCard(padding: 14, radius: TCRadius.control)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        context.insert(ImportantDate(title: title.trimmingCharacters(in: .whitespaces),
                                     date: date, kind: kind, repeatsYearly: repeats))
        try? context.save()
        dismiss()
    }
}
