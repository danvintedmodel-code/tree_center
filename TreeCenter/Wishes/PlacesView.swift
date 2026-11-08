import SwiftData
import SwiftUI
import TreeCenterData

// Viajes. Una tarjeta por lugar, el nombre en medio y el dibujo de fondo
// disolviéndose por los cuatro lados.
//
// El difuminado es una máscara elíptica sobre la capa del dibujo, no una sombra
// encima: por eso la ilustración se funde con el fondo en vez de quedar metida
// dentro de un rectángulo con los bordes oscurecidos.

struct PlacesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Place.order) private var places: [Place]

    @State private var adding = false

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Viajes",
                           subtitle: places.isEmpty ? nil : "\(places.count) lugares guardados",
                           back: { dismiss() }) {
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Añadir lugar")
            }

            if places.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(places) { place in
                            NavigationLink { PlaceView(place: place) } label: {
                                PlaceCard(place: place)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Borrar", role: .destructive) {
                                    context.delete(place)
                                    try? context.save()
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, TCSpace.gutter)
                    .padding(.bottom, 24)
                }
                // Cada tarjeta se queda centrada al soltar: así cada lugar tiene
                // su momento en vez de ser una fila de una lista.
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) { PlaceEditor(order: places.count) }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            LineArt(canvas: PlaceArt.mountains.canvas, color: TCColor.textFaint,
                    draw: PlaceArt.mountains.drawing)
                .frame(height: 110)
                .padding(.horizontal, 40)
            Text("Ningún lugar todavía").tcSection()
            Text("Sitios a los que quieres ir. Con su presupuesto y cuándo, si ya lo sabes.")
                .tcBody()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Añadir el primero") { adding = true }
                .buttonStyle(TCPrimaryButtonStyle())
                .padding(.horizontal, 60)
                .padding(.top, 6)
            Spacer()
            Spacer()
        }
    }
}

// MARK: - La tarjeta

private struct PlaceCard: View {
    let place: Place

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(TCColor.cardSunken)

            LineArt(canvas: art.canvas, color: TCColor.textSoft, lineWidth: 1.3, draw: art.drawing)
                .padding(.horizontal, -20)
                .mask(
                    EllipticalGradient(
                        stops: [.init(color: .black, location: 0.38),
                                .init(color: .black.opacity(0.25), location: 0.72),
                                .init(color: .clear, location: 1)],
                        center: .center
                    )
                )

            VStack(spacing: 7) {
                Text(place.name)
                    .font(TCFont.font(31, .semibold))
                    .tracking(-0.9)
                    .foregroundStyle(TCColor.text)
                    .shadow(color: TCColor.bg, radius: 14)
                    .multilineTextAlignment(.center)

                Text(place.country.uppercased())
                    .font(TCFont.font(11, .semibold))
                    .tracking(2.8)
                    .foregroundStyle(TCColor.textSoft)
            }
            .padding(.horizontal, 24)

            VStack {
                Spacer()
                Text(footnote)
                    .font(TCFont.font(10))
                    .tracking(0.6)
                    .foregroundStyle(TCColor.textFaint)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 288)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TCColor.line, lineWidth: 1)
        )
    }

    private var art: PlaceArt { PlaceArt.forName(place.name) }

    private var footnote: String {
        let parts = [
            place.whenNote.isEmpty ? nil : place.whenNote,
            // Con closure y no `map(Cents.formatted)`: al pasar la función por
            // referencia, su segundo parámetro con valor por defecto deja de
            // serlo y la firma ya no encaja.
            place.budgetCents.map { Cents.formatted($0) }
        ].compactMap { $0 }
        return parts.isEmpty ? "sin fecha ni presupuesto" : parts.joined(separator: " · ")
    }
}

// MARK: - Dentro de un lugar

private struct PlaceView: View {
    @Bindable var place: Place

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var budget = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: place.name,
                           subtitle: place.country.isEmpty ? nil : place.country,
                           back: { dismiss() })

            ScrollView {
                VStack(spacing: 16) {
                    PlaceCard(place: place)

                    field("Cuándo", text: $place.whenNote, placeholder: "primavera 2027")

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Presupuesto")
                        HStack {
                            TextField("1400", text: $budget)
                                .keyboardType(.decimalPad)
                                .font(TCFont.font(15))
                                .monospacedDigit()
                                .foregroundStyle(TCColor.text)
                            Text("€").tcMicro()
                        }
                        .tcCard(padding: 14, radius: TCRadius.control)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Notas")
                        TextField("Lo que no quieres olvidar del sitio", text: $place.notes, axis: .vertical)
                            .font(TCFont.font(13))
                            .foregroundStyle(TCColor.text)
                            .lineLimit(4...10)
                            .tcCard(padding: 14, radius: TCRadius.control)
                    }

                    Text("El mapa y la galería del sitio llegan cuando entren las imágenes.")
                        .tcMicro()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            budget = place.budgetCents.map { Cents.decimal($0).formatted(.number.precision(.fractionLength(0...2))) } ?? ""
        }
        .onDisappear(perform: commit)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: label)
            TextField(placeholder, text: text)
                .font(TCFont.font(15))
                .foregroundStyle(TCColor.text)
                .tcCard(padding: 14, radius: TCRadius.control)
        }
    }

    /// Se guarda al salir: tener que acordarse de pulsar Guardar en una ficha
    /// que solo son notas sueltas es la forma más fácil de perderlas.
    private func commit() {
        let clean = budget.replacingOccurrences(of: ",", with: ".")
        place.budgetCents = Decimal(string: clean).map(Cents.from)
        try? context.save()
    }
}

// MARK: - Nuevo lugar

private struct PlaceEditor: View {
    let order: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var country = ""
    @State private var when = ""
    @State private var budget = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .font(TCFont.font(14)).foregroundStyle(TCColor.textSoft)
                Spacer()
                Text("Nuevo lugar").font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
                Spacer()
                Button("Guardar") { save() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(canSave ? TCColor.moss : TCColor.textFaint)
                    .disabled(!canSave)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 16)
            .background(TCColor.cardSunken)

            VStack(spacing: 14) {
                row("Lugar", text: $name, placeholder: "Kioto")
                row("País", text: $country, placeholder: "Japón")
                row("Cuándo", text: $when, placeholder: "primavera 2027")
                row("Presupuesto", text: $budget, placeholder: "1400", numeric: true)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 18)

            Spacer()
        }
        .background(TCColor.bg)
    }

    private func row(_ label: String, text: Binding<String>,
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

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        let clean = budget.replacingOccurrences(of: ",", with: ".")
        context.insert(Place(
            name: name.trimmingCharacters(in: .whitespaces),
            country: country.trimmingCharacters(in: .whitespaces),
            whenNote: when.trimmingCharacters(in: .whitespaces),
            budgetCents: Decimal(string: clean).map(Cents.from),
            order: order
        ))
        try? context.save()
        dismiss()
    }
}
