import SwiftData
import SwiftUI
import TreeCenterData

// La ficha de una prenda. Antes esto era un `alert` con un campo de texto, que
// servía para ponerle nombre y nada más; con la foto hace falta una hoja.
//
// La foto va en `.fit`: el PNG de una prenda viene con el fondo recortado y
// recortarlo otra vez le corta las mangas.

struct GarmentEditor: View {
    /// Nil para una prenda nueva.
    var garment: Garment? = nil
    var startIn: GarmentCategory = .hoodies

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var category: GarmentCategory = .hoodies
    @State private var color: PaletteColor = .neutral
    @State private var image: Data?
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Foto", trailing: "PNG con el fondo recortado")
                        PhotoWell(data: $image,
                                  height: 230,
                                  symbol: "tshirt",
                                  hint: "Recórtala y se monta sola",
                                  mode: .fit)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Nombre")
                        TextField("Sudadera verde", text: $name)
                            .font(TCFont.font(15))
                            .foregroundStyle(TCColor.text)
                            .tcCard(padding: 14, radius: TCRadius.control)
                    }

                    categoryGrid
                    colorRow
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .onAppear(perform: fill)
    }

    private var header: some View {
        HStack {
            Button("Cancelar") { dismiss() }
                .font(TCFont.font(14))
                .foregroundStyle(TCColor.textSoft)
            Spacer()
            Text(garment == nil ? "Nueva prenda" : "Prenda")
                .font(TCFont.font(14, .semibold))
                .foregroundStyle(TCColor.text)
            Spacer()
            Button("Guardar") { save() }
                .font(TCFont.font(14, .semibold))
                .foregroundStyle(canSave ? TCColor.moss : TCColor.textFaint)
                .disabled(!canSave)
        }
        .padding(.horizontal, TCSpace.gutter)
        .padding(.vertical, 16)
        .background(TCColor.cardSunken)
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "Dónde va")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                      spacing: 8) {
                ForEach(GarmentCategory.allCases) { option in
                    Button { category = option } label: {
                        VStack(spacing: 7) {
                            option.icon(option == category ? TCColor.moss : TCColor.textSoft, size: 24)
                            Text(option.label)
                                .font(TCFont.font(9))
                                .foregroundStyle(option == category ? TCColor.moss : TCColor.textMicro)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(option == category ? TCColor.mossWell : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(option == category ? TCColor.moss : TCColor.line,
                                              lineWidth: option == category ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Para cuando la prenda no tiene foto: el color es lo que la distingue en
    /// la tira de abajo.
    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "Color", trailing: "si no hay foto")
            HStack(spacing: 10) {
                ForEach(PaletteColor.allCases) { option in
                    Button { color = option } label: {
                        Circle()
                            .fill(swatch(option))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(option == color ? TCColor.text : TCColor.line,
                                                lineWidth: option == color ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.rawValue)
                }
                Spacer()
            }
        }
    }

    private func swatch(_ option: PaletteColor) -> Color {
        switch option {
        case .moss: return TCColor.moss
        case .blue: return TCColor.blue
        case .sand: return TCColor.sand
        case .clay: return TCColor.clay
        case .lilac: return TCColor.lilac
        case .neutral: return TCColor.textSoft
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty || image != nil
    }

    /// Una sola vez: `onAppear` se dispara otra vez al volver de la cámara, y
    /// sin esto la foto recién hecha se borraría con lo que hay guardado.
    private func fill() {
        guard !loaded else { return }
        loaded = true

        guard let garment else {
            category = startIn
            return
        }
        name = garment.name
        category = garment.category
        color = garment.color
        image = garment.image
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = clean.isEmpty ? category.label : clean

        if let garment {
            garment.name = title
            garment.categoryRaw = category.rawValue
            garment.colorRaw = color.rawValue
            garment.image = image
        } else {
            let new = Garment(name: title, category: category, color: color)
            new.image = image
            context.insert(new)
        }

        try? context.save()
        dismiss()
    }
}
