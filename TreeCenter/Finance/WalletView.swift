import SwiftData
import SwiftUI
import TreeCenterData

// Dentro de una cartera. El saldo arriba en grande, lo que entra y sale debajo,
// y la barra del tope solo si le has puesto uno: una barra contra nada no dice
// nada.

struct WalletView: View {
    let wallet: Wallet

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var addingSection = false
    @State private var newSectionName = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: wallet.name, subtitle: subtitle, back: { dismiss() }) {
                Circle().fill(wallet.color.swiftUI).frame(width: 11, height: 11)
            }

            ScrollView {
                VStack(spacing: 18) {
                    summary
                    sectionsBlock
                    blocksRow
                    movementsBlock
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Nueva sección", isPresented: $addingSection) {
            TextField("Nombre", text: $newSectionName)
            Button("Cancelar", role: .cancel) { newSectionName = "" }
            Button("Crear") { createSection() }
        } message: {
            Text("Empieza como etiqueta. Puedes convertirla en subcartera cuando quieras ponerle tope.")
        }
    }

    private var month: DateInterval { Calendar.current.monthInterval() }

    private var subtitle: String {
        "entra \(Cents.formatted(wallet.earnedCents(in: month))) · sale \(Cents.formatted(wallet.spentCents(in: month)))"
    }

    // MARK: - Resumen

    private var summary: some View {
        HStack(spacing: 16) {
            ZStack {
                TCRing(value: capProgress, tint: wallet.color.swiftUI, lineWidth: 6)
                Text(capLabel)
                    .font(TCFont.font(12, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(TCColor.text)
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 5) {
                Text("SALDO").tcLabel()
                Text(Cents.formatted(wallet.balanceCents))
                    .font(TCFont.font(25, .semibold))
                    .monospacedDigit()
                    .tracking(-0.7)
                    .foregroundStyle(TCColor.text)
                if let cap = wallet.monthlyCapCents {
                    Text("gasto \(Cents.formatted(wallet.spentCents(in: month))) de \(Cents.formatted(cap))")
                        .tcMicro()
                } else {
                    Text("sin tope de gasto").tcMicro()
                }
            }
            Spacer(minLength: 0)
        }
        .tcCard(padding: 16)
    }

    private var capProgress: Double {
        guard let cap = wallet.monthlyCapCents, cap > 0 else { return 0 }
        return Double(wallet.spentCents(in: month)) / Double(cap)
    }

    private var capLabel: String {
        guard wallet.monthlyCapCents != nil else { return "—" }
        return (capProgress * 100).formatted(.number.precision(.fractionLength(0))) + "%"
    }

    // MARK: - Secciones

    private var sectionsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Secciones")

            VStack(spacing: 0) {
                ForEach(wallet.orderedSections) { section in
                    sectionRow(section)
                    Divider().overlay(TCColor.line)
                }

                Button { addingSection = true } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        Text("Añadir sección").font(TCFont.font(12.5))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(TCColor.textMicro)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .tcCard(padding: 14)
        }
    }

    private func sectionRow(_ section: WalletSection) -> some View {
        HStack(spacing: 10) {
            Menu {
                Button("Etiqueta") { change(section, to: .tag) }
                Button("Subcartera") { change(section, to: .wallet) }
            } label: {
                Text(section.kind.label.uppercased())
                    .font(TCFont.font(9, .semibold))
                    .tracking(0.6)
                    .foregroundStyle(section.kind == .wallet ? TCColor.onMoss : TCColor.textSoft)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(section.kind == .wallet ? TCColor.moss : Color.clear)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(section.kind == .wallet ? Color.clear : TCColor.lineStrong,
                                         lineWidth: 1)
                    )
            }

            Text(section.name).font(TCFont.font(13.5)).foregroundStyle(TCColor.text)
            Spacer(minLength: 8)
            Text(Cents.formatted(section.spentCents(in: month)))
                .font(TCFont.font(12.5))
                .monospacedDigit()
                .foregroundStyle(TCColor.textSoft)
        }
        .padding(.vertical, 11)
    }

    /// Cambiar de clase no toca los movimientos: lo apuntado se queda donde está.
    private func change(_ section: WalletSection, to kind: WalletKind) {
        section.kindRaw = kind.rawValue
        try? context.save()
    }

    private func createSection() {
        let name = newSectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        newSectionName = ""
        guard !name.isEmpty else { return }

        let section = WalletSection(name: name, kind: .tag, order: wallet.sections.count)
        context.insert(section)
        section.wallet = wallet
        try? context.save()
    }

    // MARK: - Bloques

    private var blocksRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Bloques de esta cartera")

            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    block("Media/día", Cents.formatted(dailyAverage))
                    block("Mayor gasto", Cents.formatted(biggest))
                    block("Movimientos", "\(allMovements.count)")
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func block(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(TCFont.font(10)).foregroundStyle(TCColor.textMicro)
            Text(value)
                .font(TCFont.font(15, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(minWidth: 96, alignment: .leading)
        .tcCard(padding: 0, radius: TCRadius.control)
    }

    private var dailyAverage: Int {
        let day = Calendar.current.component(.day, from: .now)
        guard day > 0 else { return 0 }
        return wallet.spentCents(in: month) / day
    }

    private var biggest: Int {
        wallet.movements.filter { $0.kind == .expense }.map(\.amountCents).max() ?? 0
    }

    // MARK: - Movimientos

    private var allMovements: [Movement] {
        (wallet.movements + wallet.incomingTransfers).sorted { $0.date > $1.date }
    }

    private var movementsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Movimientos")

            if allMovements.isEmpty {
                Text("Nada apuntado en esta cartera todavía.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allMovements.prefix(12).enumerated()), id: \.element.persistentModelID) { index, movement in
                        movementRow(movement)
                        if index < min(12, allMovements.count) - 1 {
                            Divider().overlay(TCColor.line)
                        }
                    }
                }
                .tcCard(padding: 14)
            }
        }
    }

    private func movementRow(_ movement: Movement) -> some View {
        let incoming = movement.destination?.persistentModelID == wallet.persistentModelID

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(movement.concept.isEmpty ? movement.kind.label : movement.concept)
                    .font(TCFont.font(13.5))
                    .foregroundStyle(TCColor.text)
                Text(caption(movement, incoming: incoming)).tcMicro()
            }
            Spacer(minLength: 8)

            // Un clip pequeño y nada más: que se vea que el gasto tiene recibo
            // sin que el ticket ocupe la fila.
            if movement.receipt != nil {
                Image(systemName: "paperclip")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(TCColor.textFaint)
            }

            Text(figure(movement, incoming: incoming))
                .font(TCFont.font(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(tint(movement, incoming: incoming))
        }
        .padding(.vertical, 11)
    }

    private func caption(_ movement: Movement, incoming: Bool) -> String {
        let when = movement.date.formatted(.dateTime.day().month(.abbreviated))
        switch movement.kind {
        case .transfer: return (incoming ? "Traspaso recibido" : "Traspaso") + " · " + when
        case .income: return "Ingreso · " + when
        case .expense: return (movement.section?.name ?? "Gasto") + " · " + when
        }
    }

    private func figure(_ movement: Movement, incoming: Bool) -> String {
        let value = Cents.formatted(movement.amountCents)
        switch movement.kind {
        case .expense: return "− " + value
        case .income: return "+ " + value
        case .transfer: return (incoming ? "← " : "→ ") + value
        }
    }

    private func tint(_ movement: Movement, incoming: Bool) -> Color {
        switch movement.kind {
        case .income: return TCColor.moss
        case .transfer: return TCColor.textSoft
        case .expense: return TCColor.text
        }
    }
}
