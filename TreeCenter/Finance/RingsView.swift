import SwiftData
import SwiftUI
import TreeCenterData

// Configurar los aros. La vista previa va arriba y viva: cambiar un color y
// tener que volver atrás para ver cómo quedó es insufrible.

struct RingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Wallet.order) private var wallets: [Wallet]
    @Query private var settings: [FinanceSettings]

    @State private var editingColorOf: PersistentIdentifier?

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Aros", back: { dismiss() }) {
                Button("Listo") { dismiss() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(TCColor.moss)
            }

            ScrollView {
                VStack(spacing: 20) {
                    preview
                    ringList
                    colorRow
                    thicknessRow
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var config: FinanceSettings? { settings.first }
    private var metric: WalletMetric { config?.metric ?? .monthSpend }
    private var month: DateInterval { Calendar.current.monthInterval() }
    private var visible: [Wallet] { wallets.filter(\.showsAsRing) }
    private var total: Int { WalletFigures.total(wallets, metric: metric, month: month) }

    private var thickness: CGFloat {
        switch config?.ringThickness ?? 1 {
        case 0: return 9
        case 2: return 17
        default: return 13
        }
    }

    // MARK: - Vista previa

    private var preview: some View {
        VStack(spacing: 10) {
            ConcentricRings(rings: rings, lineWidth: thickness)
                .frame(width: 160, height: 160)
            Text("VISTA PREVIA EN VIVO").tcLabel()
        }
        .frame(maxWidth: .infinity)
        .tcCard(padding: 16, sunken: true)
    }

    private var rings: [ConcentricRings.Ring] {
        var result: [ConcentricRings.Ring] = [
            .init(id: "total", value: total > 0 ? 0.76 : 0, color: TCColor.neutralData)
        ]
        for wallet in visible {
            result.append(.init(
                id: wallet.persistentModelID.hashValue.description,
                value: WalletFigures.fill(wallet, metric: metric, month: month, total: total),
                color: wallet.color.swiftUI
            ))
        }
        return result
    }

    // MARK: - Qué aros se ven

    private var ringList: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Qué aros se ven")

            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    Circle().fill(TCColor.neutralData).frame(width: 11, height: 11)
                    Text("Total").font(TCFont.font(13.5)).foregroundStyle(TCColor.text)
                    Spacer(minLength: 8)
                    Text("exterior · fijo").tcMicro()
                }
                .padding(.vertical, 11)

                Divider().overlay(TCColor.line)

                ForEach(Array(wallets.enumerated()), id: \.element.persistentModelID) { index, wallet in
                    ringRow(wallet)
                    if index < wallets.count - 1 { Divider().overlay(TCColor.line) }
                }
            }
            .tcCard(padding: 14)

            Text(tooManyWarning ?? "El orden de la lista es el orden de fuera hacia dentro.")
                .font(TCFont.font(11))
                .foregroundStyle(tooManyWarning == nil ? TCColor.textMicro : TCColor.clay)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Pasados cuatro o cinco aros el gráfico deja de leerse. En vez de impedirlo
    /// a la brava, se dice: los de más abajo simplemente no se dibujan.
    private var tooManyWarning: String? {
        let extra = visible.count + 1 - ConcentricRings.maxRings
        guard extra > 0 else { return nil }
        return "Con \(visible.count + 1) aros el gráfico deja de leerse. Los \(extra) últimos no se dibujan."
    }

    private func ringRow(_ wallet: Wallet) -> some View {
        HStack(spacing: 11) {
            Button { editingColorOf = wallet.persistentModelID } label: {
                Circle()
                    .fill(wallet.color.swiftUI)
                    .frame(width: 11, height: 11)
                    .overlay(
                        Circle()
                            .stroke(TCColor.text, lineWidth: editingColorOf == wallet.persistentModelID ? 1.5 : 0)
                            .padding(-3)
                    )
            }
            .buttonStyle(.plain)

            Text(wallet.name)
                .font(TCFont.font(13.5))
                .foregroundStyle(wallet.showsAsRing ? TCColor.text : TCColor.textFaint)

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { wallet.showsAsRing },
                set: { wallet.showsAsRing = $0; try? context.save() }
            ))
            .labelsHidden()
            .tint(TCColor.moss)
        }
        .padding(.vertical, 9)
    }

    // MARK: - Color

    @ViewBuilder
    private var colorRow: some View {
        if let target = wallets.first(where: { $0.persistentModelID == editingColorOf }) {
            VStack(alignment: .leading, spacing: 12) {
                TCSectionLabel(text: "Color de \(target.name)")

                HStack(spacing: 0) {
                    ForEach(PaletteColor.allCases) { option in
                        Button {
                            target.colorRaw = option.rawValue
                            try? context.save()
                        } label: {
                            Circle()
                                .fill(option.swiftUI)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(TCColor.text, lineWidth: option == target.color ? 2 : 0)
                                        .padding(-4)
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(option.label)
                    }
                }

                Text("Seis colores que se leen igual en claro y en oscuro.")
                    .font(TCFont.font(11))
                    .foregroundStyle(TCColor.textMicro)
            }
        }
    }

    // MARK: - Grosor

    private var thicknessRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Grosor")
            HStack(spacing: 7) {
                ForEach(Array(["Fino", "Medio", "Grueso"].enumerated()), id: \.offset) { index, label in
                    Button { setThickness(index) } label: {
                        TCChip(text: label, selected: (config?.ringThickness ?? 1) == index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func setThickness(_ value: Int) {
        if let config {
            config.ringThickness = value
        } else {
            context.insert(FinanceSettings(ringThickness: value))
        }
        try? context.save()
    }
}
