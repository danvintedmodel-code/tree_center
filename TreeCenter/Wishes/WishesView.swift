import SwiftData
import SwiftUI
import TreeCenterData

// Caprichos. La sección más visual de la app: cada bloque con su dibujo propio,
// para distinguirlos de un vistazo sin leer.

struct WishesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \WishBlock.order) private var blocks: [WishBlock]
    @Query(sort: \Wallet.order) private var wallets: [Wallet]
    @Query private var places: [Place]

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Caprichos", back: { dismiss() })

            ScrollView {
                VStack(spacing: 14) {
                    grid
                    travelCard
                    monthCard
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .task { ensureBlocks() }
    }

    private var gridBlocks: [WishBlock] {
        blocks.filter { $0.kind != .travel }
    }

    private var travelBlock: WishBlock? {
        blocks.first { $0.kind == .travel }
    }

    // MARK: - Los bloques

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                  spacing: 14) {
            ForEach(gridBlocks) { block in
                NavigationLink { WishBlockView(block: block) } label: {
                    VStack(spacing: 0) {
                        block.kind.art(TCColor.textSoft)
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .background(TCColor.well)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(block.kind.label)
                                .font(TCFont.font(15, .medium))
                                .foregroundStyle(TCColor.text)
                            Text(countLabel(block.items.count))
                                .tcMicro()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 14)
                    }
                    .background(TCColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: TCRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TCRadius.card, style: .continuous)
                            .stroke(TCColor.line, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func countLabel(_ count: Int) -> String {
        count == 0 ? "vacío" : "\(count) guardado\(count == 1 ? "" : "s")"
    }

    // MARK: - Viajes

    private var travelCard: some View {
        NavigationLink { PlacesView() } label: {
            HStack(spacing: 0) {
                WishKind.travel.art(TCColor.textSoft)
                    .frame(width: 132, height: 92)
                    .background(TCColor.well)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Viajes")
                            .font(TCFont.font(16, .medium))
                            .foregroundStyle(TCColor.text)
                        Text(places.isEmpty ? "sin lugares" : "\(places.count) lugares")
                            .tcMicro()
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TCColor.textFaint)
                }
                .padding(.horizontal, 16)
            }
            .background(TCColor.card)
            .clipShape(RoundedRectangle(cornerRadius: TCRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TCRadius.card, style: .continuous)
                    .stroke(TCColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Este mes

    /// No es un contador aparte: es la cartera Caprichos de Finanzas asomada
    /// aquí. Mismo dato en los dos sitios, se apunte desde donde se apunte.
    private var treatsWallet: Wallet? {
        wallets.first { $0.name.localizedCaseInsensitiveCompare("Caprichos") == .orderedSame }
    }

    @ViewBuilder
    private var monthCard: some View {
        if let wallet = treatsWallet {
            let month = Calendar.current.monthInterval()
            let spent = wallet.spentCents(in: month)

            NavigationLink { WalletView(wallet: wallet) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 8) {
                            Circle().fill(wallet.color.swiftUI).frame(width: 9, height: 9)
                            Text("Cartera Caprichos").tcBody()
                        }
                        Spacer(minLength: 8)
                        Text(Cents.formatted(spent))
                            .font(TCFont.font(17, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(TCColor.text)
                    }

                    if let cap = wallet.monthlyCapCents, cap > 0 {
                        TCProgressBar(value: Double(spent) / Double(cap), tint: wallet.color.swiftUI)
                        Text("de un tope de \(Cents.formatted(cap)) que te pusiste tú").tcMicro()
                    } else {
                        Text("sin tope este mes").tcMicro()
                    }
                }
                .tcCard(padding: 16)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    /// Los cinco bloques existen siempre. Si el primer arranque fue anterior a
    /// esta pantalla, se completan al entrar en vez de salir medio vacía.
    private func ensureBlocks() {
        let missing = WishKind.allCases.filter { kind in
            !blocks.contains { $0.kind == kind }
        }
        guard !missing.isEmpty else { return }
        for (offset, kind) in missing.enumerated() {
            context.insert(WishBlock(kind: kind, order: blocks.count + offset))
        }
        try? context.save()
    }
}

// MARK: - Dentro de un bloque

struct WishBlockView: View {
    let block: WishBlock

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var adding = false
    @State private var name = ""
    @State private var price = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: block.kind.label,
                           subtitle: block.items.isEmpty ? nil : "\(block.items.count) guardados",
                           back: { dismiss() }) {
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Añadir capricho")
            }

            ScrollView {
                VStack(spacing: 14) {
                    block.kind.art(TCColor.textFaint)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .tcCard(padding: 12, sunken: true)

                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Text("Nada guardado aquí").tcRow()
                            Text("Lo que te apetece y todavía no te has comprado.")
                                .tcMicro()
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                        .tcCard(padding: 16, sunken: true)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, item in
                                HStack {
                                    Text(item.name).font(TCFont.font(14)).foregroundStyle(TCColor.text)
                                    Spacer(minLength: 8)
                                    if let cents = item.priceCents {
                                        Text(Cents.formatted(cents))
                                            .font(TCFont.font(13))
                                            .monospacedDigit()
                                            .foregroundStyle(TCColor.textSoft)
                                    }
                                }
                                .padding(.vertical, 12)
                                .contextMenu {
                                    Button("Borrar", role: .destructive) {
                                        context.delete(item)
                                        try? context.save()
                                    }
                                }

                                if index < items.count - 1 { Divider().overlay(TCColor.line) }
                            }
                        }
                        .tcCard(padding: 14)

                        if let sum = totalCents {
                            Text("Todo junto: \(Cents.formatted(sum))")
                                .tcMicro()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Nuevo capricho", isPresented: $adding) {
            TextField("Qué es", text: $name)
            TextField("Precio en euros (opcional)", text: $price)
                .keyboardType(.decimalPad)
            Button("Cancelar", role: .cancel) { name = ""; price = "" }
            Button("Guardar") { add() }
        }
    }

    private var items: [WishItem] {
        block.items.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalCents: Int? {
        let known = items.compactMap(\.priceCents)
        return known.isEmpty ? nil : known.reduce(0, +)
    }

    private func add() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let euros = Decimal(string: price.replacingOccurrences(of: ",", with: "."))
        name = ""
        price = ""
        guard !title.isEmpty else { return }

        let item = WishItem(name: title, priceCents: euros.map(Cents.from))
        context.insert(item)
        item.block = block
        try? context.save()
    }
}
