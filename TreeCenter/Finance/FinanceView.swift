import SwiftData
import SwiftUI
import TreeCenterCore
import TreeCenterData

// Finanzas. Los aros arriba, las carteras en medio y el reparto abajo del todo,
// fijo: es la vista rápida y no debería hacer falta hacer scroll para verla.
//
// El selector de qué miden los aros manda también sobre el reparto. No tendría
// sentido que el gráfico hable de saldo y el recuadro de gasto.

struct FinanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Wallet.order) private var wallets: [Wallet]
    @Query private var settings: [FinanceSettings]

    @State private var adding = false
    @State private var creatingWallet = false
    @State private var newWalletName = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Finanzas", back: { dismiss() }) {
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TCColor.onMoss)
                        .frame(width: 36, height: 36)
                        .background(TCColor.moss)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Anotar movimiento")
            }

            ScrollView {
                VStack(spacing: 16) {
                    metricChips
                    ringsBlock
                    legend
                    walletCards
                    newWalletButton
                    allocationCard
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)

            splitCard
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 8)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) {
            MovementEditorView()
                .presentationDetents([.large])
        }
        .alert("Nueva cartera", isPresented: $creatingWallet) {
            TextField("Nombre", text: $newWalletName)
            Button("Cancelar", role: .cancel) { newWalletName = "" }
            Button("Crear") { createWallet() }
        }
    }

    // MARK: - Estado

    private var config: FinanceSettings? { settings.first }
    private var metric: WalletMetric { config?.metric ?? .monthSpend }
    private var month: DateInterval { Calendar.current.monthInterval() }

    private var total: Int { WalletFigures.total(wallets, metric: metric, month: month) }
    private var ringWallets: [Wallet] { wallets.filter(\.showsAsRing) }

    private var thickness: CGFloat {
        switch config?.ringThickness ?? 1 {
        case 0: return 9
        case 2: return 17
        default: return 13
        }
    }

    // MARK: - Selector

    private var metricChips: some View {
        HStack(spacing: 7) {
            ForEach(WalletMetric.allCases) { option in
                Button { setMetric(option) } label: {
                    TCChip(text: option.label, selected: option == metric)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func setMetric(_ option: WalletMetric) {
        if let config {
            config.metricRaw = option.rawValue
        } else {
            context.insert(FinanceSettings(metric: option))
        }
        try? context.save()
    }

    // MARK: - Aros

    private var ringsBlock: some View {
        ZStack {
            ConcentricRings(rings: ringData, lineWidth: thickness)
            VStack(spacing: 2) {
                Text("TOTAL").tcLabel()
                Text(Cents.formatted(total))
                    .font(TCFont.font(25, .semibold))
                    .monospacedDigit()
                    .tracking(-0.7)
                    .foregroundStyle(TCColor.text)
                if let cap = WalletFigures.totalCap(wallets), metric == .monthSpend {
                    Text("de \(Cents.formatted(cap))").tcMicro()
                }
            }
        }
        .frame(width: 206, height: 206)
        .padding(.top, 4)
    }

    private var ringData: [ConcentricRings.Ring] {
        var result: [ConcentricRings.Ring] = []

        // El Total va fuera siempre. Contra el tope conjunto si lo hay; si no,
        // lleno, porque un total contra nada no significa nada.
        let cap = WalletFigures.totalCap(wallets)
        let totalFill = metric == .monthSpend && (cap ?? 0) > 0
            ? Double(total) / Double(cap!)
            : (total > 0 ? 1 : 0)
        result.append(.init(id: "total", value: totalFill, color: TCColor.neutralData))

        for wallet in ringWallets {
            result.append(.init(
                id: wallet.persistentModelID.hashValue.description,
                value: WalletFigures.fill(wallet, metric: metric, month: month, total: total),
                color: wallet.color.swiftUI
            ))
        }
        return result
    }

    private var legend: some View {
        HStack(spacing: 10) {
            legendDot("Total", TCColor.neutralData)
            ForEach(ringWallets.prefix(ConcentricRings.maxRings - 1)) { wallet in
                legendDot(wallet.name, wallet.color.swiftUI)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendDot(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name).font(TCFont.font(11)).foregroundStyle(TCColor.textSoft)
        }
    }

    // MARK: - Carteras

    private var walletCards: some View {
        VStack(spacing: 10) {
            ForEach(wallets) { wallet in
                NavigationLink { WalletView(wallet: wallet) } label: {
                    walletCard(wallet)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func walletCard(_ wallet: Wallet) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(wallet.color.swiftUI).frame(width: 9, height: 9)
                    Text(wallet.name).tcRow()
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Text(Cents.formatted(wallet.balanceCents))
                        .font(TCFont.font(15, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(TCColor.text)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TCColor.textFaint)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    block("Saldo", Cents.formatted(wallet.balanceCents))
                    block("Entra", Cents.formatted(wallet.earnedCents(in: month)))
                    block("Sale", Cents.formatted(wallet.spentCents(in: month)))
                    if let cap = wallet.monthlyCapCents {
                        block("Tope mes", Cents.formatted(cap))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .tcCard(padding: 14, radius: TCRadius.card)
    }

    private func block(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(TCFont.font(10)).foregroundStyle(TCColor.textMicro)
            Text(value)
                .font(TCFont.font(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.text)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(minWidth: 86, alignment: .leading)
        .background(TCColor.well)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var newWalletButton: some View {
        HStack(spacing: 10) {
            Button("Nueva cartera") { creatingWallet = true }
                .buttonStyle(TCGhostButtonStyle(dashed: true))

            NavigationLink { RingsView() } label: {
                Text("Aros")
                    .font(TCFont.font(15, .medium))
                    .foregroundStyle(TCColor.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(TCColor.lineStrong, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Reparto

    private var splitCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REPARTO · \(metric.label.uppercased())").tcLabel()

            if total == 0 {
                Text("Nada que repartir todavía este mes.")
                    .tcMicro()
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(wallets) { wallet in
                        HStack(spacing: 10) {
                            Text(wallet.name)
                                .font(TCFont.font(12))
                                .foregroundStyle(TCColor.textSoft)
                                .frame(width: 74, alignment: .leading)
                                .lineLimit(1)

                            TCProgressBar(
                                value: WalletFigures.share(wallet, metric: metric, month: month, total: total),
                                tint: wallet.color.swiftUI,
                                height: 5
                            )

                            Text(percent(wallet))
                                .font(TCFont.font(12, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(TCColor.text)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(TCColor.cardSunken)
        .clipShape(RoundedRectangle(cornerRadius: TCRadius.cardLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TCRadius.cardLarge, style: .continuous)
                .stroke(TCColor.line, lineWidth: 1)
        )
    }

    private func percent(_ wallet: Wallet) -> String {
        let share = WalletFigures.share(wallet, metric: metric, month: month, total: total)
        return (share * 100).formatted(.number.precision(.fractionLength(0))) + " %"
    }

    // MARK: - Acciones

    // MARK: - El reparto de lo que entra

    /// Qué parte de cada ingreso va a cada cartera. Entre todas no pasan de
    /// 100 %; lo que falte se queda en la cartera donde entra el ingreso.
    private var allocationCard: some View {
        let percents = wallets.map(\.allocationPercent)
        let assigned = 100 - IncomeSplit.unassigned(percents)

        return VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Reparto de lo que entra", trailing: "\(assigned) de 100 %")

            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        ForEach(wallets) { wallet in
                            Rectangle()
                                .fill(wallet.color.swiftUI)
                                .frame(width: proxy.size.width * CGFloat(wallet.allocationPercent) / 100)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 10)
                .background(TCColor.track)
                .clipShape(Capsule())

                ForEach(Array(wallets.enumerated()), id: \.element.persistentModelID) { index, wallet in
                    HStack(spacing: 10) {
                        Circle().fill(wallet.color.swiftUI).frame(width: 8, height: 8)
                        Text(wallet.name).font(TCFont.font(13.5)).foregroundStyle(TCColor.text)
                        Spacer(minLength: 8)
                        percentButton("−", enabled: wallet.allocationPercent > 0) {
                            wallet.allocationPercent = max(0, wallet.allocationPercent - 5)
                        }
                        Text("\(wallet.allocationPercent) %")
                            .font(TCFont.font(14, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(TCColor.text)
                            .frame(width: 48)
                        percentButton("+", enabled: wallet.allocationPercent + 5 <= IncomeSplit.maxPercent(for: index, in: percents)) {
                            wallet.allocationPercent = min(IncomeSplit.maxPercent(for: index, in: percents),
                                                           wallet.allocationPercent + 5)
                        }
                    }
                }

                Text(assigned < 100
                     ? "Sin asignar: \(100 - assigned) %. Ese trozo se queda en la cartera donde apuntes el ingreso."
                     : "Todo repartido.")
                    .font(TCFont.font(11))
                    .foregroundStyle(assigned < 100 ? TCColor.textMicro : TCColor.moss)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .tcCard(padding: 16)
        }
    }

    private func percentButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            try? context.save()
        } label: {
            Text(symbol)
                .font(TCFont.font(15, .medium))
                .foregroundStyle(TCColor.textSoft)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func createWallet() {
        let name = newWalletName.trimmingCharacters(in: .whitespacesAndNewlines)
        newWalletName = ""
        guard !name.isEmpty else { return }

        let palette = PaletteColor.allCases
        context.insert(Wallet(name: name,
                              color: palette[wallets.count % palette.count],
                              order: wallets.count))
        try? context.save()
    }
}
