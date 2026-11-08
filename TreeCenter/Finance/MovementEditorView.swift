import SwiftData
import SwiftUI
import TreeCenterData

// Anotar un movimiento.
//
// Es la pantalla que más se va a usar de toda la app, así que todo lo demás se
// subordina a que apuntar un gasto cueste tres toques: escribir, tocar cartera,
// guardar. El tipo abre en Gasto, que es lo que harás casi siempre.
//
// El teclado va por céntimos: tecleas 1240 y sale 12,40 €. Por eso no hay tecla
// de coma — sobra — y en su sitio va un "00", que es lo que de verdad se usa
// cuando el importe es redondo.

struct MovementEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Wallet.order) private var wallets: [Wallet]

    @State private var kind: MovementKind = .expense
    @State private var cents = 0
    @State private var walletID: PersistentIdentifier?
    @State private var destinationID: PersistentIdentifier?
    @State private var sectionID: PersistentIdentifier?
    @State private var concept = ""
    @State private var date = Date()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    kindPicker.padding(.bottom, 20)
                    amount
                    hint.padding(.bottom, 20)
                    walletSection
                    if kind == .transfer { destinationSection }
                    if !sections.isEmpty && kind != .transfer { sectionChips }
                    detailRow.padding(.top, 16)
                }
                .padding(.horizontal, TCSpace.gutter)
            }
            .scrollIndicators(.hidden)

            keypad
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 10)
        }
        .background(TCColor.cardSunken)
        .onAppear { if walletID == nil { walletID = wallets.first?.persistentModelID } }
    }

    // MARK: - Cabecera

    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(TCColor.lineStrong)
                .frame(width: 38, height: 4)
                .padding(.top, 10)

            HStack {
                Button("Cancelar") { dismiss() }
                    .font(TCFont.font(14))
                    .foregroundStyle(TCColor.textSoft)
                Spacer()
                Text("Nuevo movimiento")
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(TCColor.text)
                Spacer()
                Button("Guardar") { save() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(canSave ? TCColor.moss : TCColor.textFaint)
                    .disabled(!canSave)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Tipo

    private var kindPicker: some View {
        HStack(spacing: 3) {
            ForEach(MovementKind.allCases) { option in
                Button { kind = option } label: {
                    Text(option.label)
                        .font(TCFont.font(13, option == kind ? .semibold : .regular))
                        .foregroundStyle(option == kind ? TCColor.text : TCColor.textSoft)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(option == kind ? TCColor.card : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(TCColor.well)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    // MARK: - Importe

    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(signPrefix)
                .font(TCFont.font(40, .semibold))
                .foregroundStyle(kind == .income ? TCColor.moss : TCColor.text)
            Text(Cents.decimal(cents).formatted(.number.precision(.fractionLength(2))))
                .font(TCFont.font(42, .semibold))
                .monospacedDigit()
                .tracking(-1.4)
                .foregroundStyle(cents == 0 ? TCColor.textFaint : TCColor.text)
            Text(" €")
                .font(TCFont.font(23, .medium))
                .foregroundStyle(TCColor.textMicro)
        }
        .frame(maxWidth: .infinity)
    }

    private var signPrefix: String {
        switch kind {
        case .expense: return "− "
        case .income: return "+ "
        case .transfer: return ""
        }
    }

    private var hint: some View {
        Text(kind == .transfer
             ? "Un traspaso no cuenta como gasto: solo cambia el dinero de sitio."
             : "El signo lo pone el tipo, tú solo la cifra.")
            .tcMicro()
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    // MARK: - Carteras

    private var selectedWallet: Wallet? {
        wallets.first { $0.persistentModelID == walletID }
    }

    private var sections: [WalletSection] { selectedWallet?.orderedSections ?? [] }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: kind == .income ? "Dónde entra" : (kind == .transfer ? "De" : "Cartera"))
            chipRow(selected: walletID) { id in
                walletID = id
                sectionID = nil
                if destinationID == id { destinationID = nil }
            }
        }
        .padding(.bottom, 12)
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "A")
            chipRow(selected: destinationID, excluding: walletID) { destinationID = $0 }
        }
        .padding(.bottom, 12)
    }

    private func chipRow(selected: PersistentIdentifier?,
                         excluding: PersistentIdentifier? = nil,
                         pick: @escaping (PersistentIdentifier) -> Void) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(wallets.filter { $0.persistentModelID != excluding }) { wallet in
                    Button { pick(wallet.persistentModelID) } label: {
                        TCChip(text: wallet.name,
                               selected: wallet.persistentModelID == selected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var sectionChips: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "Sección", trailing: "opcional")
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(sections) { item in
                        Button {
                            sectionID = sectionID == item.persistentModelID ? nil : item.persistentModelID
                        } label: {
                            TCChip(text: item.name, selected: item.persistentModelID == sectionID)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Detalle

    private var detailRow: some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Concepto").font(TCFont.font(10)).foregroundStyle(TCColor.textMicro)
                TextField("Metro de vuelta", text: $concept)
                    .font(TCFont.font(13))
                    .foregroundStyle(TCColor.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TCColor.well)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    // MARK: - Teclado

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "00", "0", "⌫"]

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button { press(key) } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left")
                                .font(.system(size: 19, weight: .light))
                        } else {
                            Text(key).font(TCFont.font(21, .medium))
                        }
                    }
                    .foregroundStyle(TCColor.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(key == "⌫" || key == "00" ? TCColor.well : TCColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func press(_ key: String) {
        switch key {
        case "⌫": cents /= 10
        case "00": cents = min(cents * 100, 99_999_999)
        default:
            guard let digit = Int(key) else { return }
            cents = min(cents * 10 + digit, 99_999_999)
        }
    }

    // MARK: - Guardar

    private var canSave: Bool {
        guard cents > 0, walletID != nil else { return false }
        if kind == .transfer { return destinationID != nil && destinationID != walletID }
        return true
    }

    private func save() {
        guard let wallet = selectedWallet else { return }

        let movement = Movement(
            amountCents: cents,
            kind: kind,
            date: date,
            concept: concept.trimmingCharacters(in: .whitespacesAndNewlines),
            wallet: wallet,
            section: sections.first { $0.persistentModelID == sectionID },
            destination: wallets.first { $0.persistentModelID == destinationID }
        )

        guard movement.isValid else { return }
        context.insert(movement)
        try? context.save()
        dismiss()
    }
}
