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
    @State private var editing: WishItem?

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
                                HStack(spacing: 11) {
                                    PhotoThumb(data: item.image, side: 34, symbol: "photo")
                                    Text(item.name).font(TCFont.font(14)).foregroundStyle(TCColor.text)
                                    Spacer(minLength: 8)
                                    if let cents = item.priceCents {
                                        Text(Cents.formatted(cents))
                                            .font(TCFont.font(13))
                                            .monospacedDigit()
                                            .foregroundStyle(TCColor.textSoft)
                                    }
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture { editing = item }
                                .contextMenu {
                                    Button("Editar") { editing = item }
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
        .sheet(isPresented: $adding) {
            WishItemEditor(block: block)
        }
        .sheet(item: $editing) { item in
            WishItemEditor(block: block, item: item)
        }
    }

    private var items: [WishItem] {
        block.items.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalCents: Int? {
        let known = items.compactMap(\.priceCents)
        return known.isEmpty ? nil : known.reduce(0, +)
    }

}

// MARK: - Un capricho

/// Un capricho es casi siempre una foto que has visto en algún sitio, así que
/// la foto va arriba y el nombre debajo, y no al revés.
private struct WishItemEditor: View {
    let block: WishBlock
    var item: WishItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var price = ""
    @State private var link = ""
    @State private var notes = ""
    @State private var image: Data?
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .font(TCFont.font(14)).foregroundStyle(TCColor.textSoft)
                Spacer()
                Text(item == nil ? "Nuevo capricho" : "Capricho")
                    .font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
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
                VStack(spacing: 15) {
                    PhotoWell(data: $image,
                              height: 210,
                              symbol: "sparkles",
                              hint: "La foto de lo que te ha gustado")

                    field("Qué es", text: $name, placeholder: "Zapatillas verdes")
                    field("Precio", text: $price, placeholder: "89", numeric: true)
                    field("Enlace", text: $link, placeholder: "donde lo viste")

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Notas")
                        TextField("La talla, el color, lo que sea", text: $notes, axis: .vertical)
                            .font(TCFont.font(13))
                            .foregroundStyle(TCColor.text)
                            .lineLimit(3...8)
                            .tcCard(padding: 14, radius: TCRadius.control)
                    }
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .onAppear(perform: fill)
    }

    private func field(_ label: String, text: Binding<String>,
                       placeholder: String, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: label)
            TextField(placeholder, text: text)
                .keyboardType(numeric ? .decimalPad : .default)
                .font(TCFont.font(15))
                .foregroundStyle(TCColor.text)
                .tcCard(padding: 14, radius: TCRadius.control)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Igual que en el armario: `onAppear` vuelve a dispararse al cerrar la
    /// cámara, y sin esta guarda la foto recién hecha se perdería.
    private func fill() {
        guard !loaded, let item else { loaded = true; return }
        loaded = true
        name = item.name
        price = item.priceCents.map { Cents.decimal($0).formatted(.number.precision(.fractionLength(0...2))) } ?? ""
        link = item.link
        notes = item.notes
        image = item.image
    }

    private func save() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let euros = Decimal(string: price.replacingOccurrences(of: ",", with: "."))
        let cents = euros.map(Cents.from)

        if let item {
            item.name = title
            item.priceCents = cents
            item.link = link.trimmingCharacters(in: .whitespaces)
            item.notes = notes
            item.image = image
        } else {
            let new = WishItem(name: title, priceCents: cents,
                               link: link.trimmingCharacters(in: .whitespaces))
            new.notes = notes
            new.image = image
            context.insert(new)
            // Después de insertar: enlazar un objeto que el contexto no conoce
            // todavía es la forma de que la relación no se guarde.
            new.block = block
        }

        try? context.save()
        dismiss()
    }
}
