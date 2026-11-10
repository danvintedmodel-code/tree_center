import SwiftData
import SwiftUI
import TreeCenterData
import UIKit

// Armario. Rail de categorías a la izquierda, maniquí en medio, prendas de la
// categoría activa abajo.
//
// Lo que falta y se nota: el giro de 360° y la ropa como malla 3D. Eso es
// RealityKit y modelado, y hasta que exista el maniquí es la figura de línea.
// El resto de la pantalla funciona entero.

struct WardrobeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var garments: [Garment]
    @Query(sort: \Outfit.createdAt, order: .reverse) private var outfits: [Outfit]

    @State private var category: GarmentCategory = .hoodies
    @State private var adding = false
    @State private var editing: Garment?
    @State private var savingOutfit = false
    @State private var outfitName = ""
    @State private var tryingOn = false

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Armario",
                           subtitle: garments.isEmpty ? nil : "\(garments.count) prendas",
                           back: { dismiss() })

            HStack(spacing: 7) {
                Button { tryingOn = false } label: { TCChip(text: "Maniquí", selected: !tryingOn) }
                    .buttonStyle(.plain)
                Button { tryingOn = true } label: { TCChip(text: "Probármelo con IA", selected: tryingOn) }
                    .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.bottom, 12)

            if tryingOn {
                TryOnInfo()
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        rail
                        mannequinBox
                    }
                    .frame(height: 388)

                    Spacer(minLength: 12)

                    strip

                    Spacer(minLength: 12)

                    buttons
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 8)
            }
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) {
            GarmentEditor(startIn: category)
        }
        .sheet(item: $editing) { garment in
            GarmentEditor(garment: garment)
        }
        .alert("Guardar conjunto", isPresented: $savingOutfit) {
            TextField("Diario", text: $outfitName)
            Button("Cancelar", role: .cancel) { outfitName = "" }
            Button("Guardar") { saveOutfit() }
        } message: {
            Text("Se guardan las \(wornGarments.count) prendas que llevas puestas.")
        }
    }

    // MARK: - Datos

    private var wornGarments: [Garment] { garments.filter(\.isWorn) }

    private var wornCategories: Set<GarmentCategory> {
        Set(wornGarments.map(\.category))
    }

    private var inCategory: [Garment] {
        garments.filter { $0.category == category }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(spacing: 8) {
            ForEach(GarmentCategory.allCases) { option in
                Button { category = option } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(option == category ? TCColor.mossWell : Color.clear)
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(option == category ? TCColor.moss : TCColor.line,
                                          lineWidth: option == category ? 1.5 : 1)
                        option.icon(option == category ? TCColor.moss : TCColor.textSoft)

                        if wornCategories.contains(option) {
                            VStack {
                                HStack {
                                    Spacer()
                                    Circle().fill(TCColor.moss)
                                        .frame(width: 5, height: 5)
                                        .padding(5)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
            }
        }
    }

    // MARK: - Maniquí

    private var mannequinBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(TCColor.cardSunken)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(TCColor.line, lineWidth: 1)
                )

            Mannequin(worn: wornGarments)
                .padding(.top, 16)
                .padding(.bottom, 30)
                .padding(.horizontal, 20)

            VStack {
                Spacer()
                Text(wornGarments.isEmpty ? "toca una prenda para ponértela" : "\(wornGarments.count) prendas puestas")
                    .font(TCFont.font(10))
                    .foregroundStyle(TCColor.textFaint)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Prendas

    private var strip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.label.uppercased()).tcLabel()
                Spacer()
                Text("\(inCategory.count)").tcMicro()
            }

            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    ForEach(inCategory) { garment in
                        Button { toggle(garment) } label: {
                            tile(garment)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Editar") { editing = garment }
                            Button("Borrar", role: .destructive) {
                                context.delete(garment)
                                try? context.save()
                            }
                        }
                    }

                    Button { adding = true } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(TCColor.lineStrong,
                                              style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(TCColor.textMicro)
                        }
                        .frame(width: 62, height: 74)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func tile(_ garment: Garment) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(garment.isWorn ? TCColor.mossWell : Color.clear)
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(garment.isWorn ? TCColor.moss : TCColor.line,
                              lineWidth: garment.isWorn ? 1.5 : 1)

            VStack(spacing: 6) {
                // La foto manda sobre el icono: una tira de prendas con sus PNG
                // se lee de un vistazo y siete iconos iguales no.
                if let data = garment.image, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                } else {
                    garment.category.icon(garment.isWorn ? TCColor.moss : TCColor.textSoft, size: 28)
                        .frame(height: 40)
                }
                Text(garment.name)
                    .font(TCFont.font(8.5))
                    .foregroundStyle(TCColor.textMicro)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }

            if garment.isWorn {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(TCColor.onMoss)
                            .frame(width: 14, height: 14)
                            .background(TCColor.moss)
                            .clipShape(Circle())
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: 62, height: 74)
    }

    /// Una prenda puesta quita la que ya hubiera de su categoría: no se llevan
    /// dos sudaderas a la vez.
    private func toggle(_ garment: Garment) {
        let wasWorn = garment.isWorn
        for other in garments where other.category == garment.category && other.isWorn {
            other.isWorn = false
        }
        garment.isWorn = !wasWorn
        try? context.save()
    }

    // MARK: - Pie

    private var buttons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button("Guardar conjunto") { savingOutfit = true }
                    .buttonStyle(TCPrimaryButtonStyle())
                    .disabled(wornGarments.isEmpty)
                    .opacity(wornGarments.isEmpty ? 0.45 : 1)

                Button("Quitar todo") { undress() }
                    .buttonStyle(TCGhostButtonStyle())
            }

            if let last = outfits.first {
                Button { wear(last) } label: {
                    Text("Ponerme «\(last.name)»")
                        .font(TCFont.font(11))
                        .foregroundStyle(TCColor.textMicro)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func undress() {
        for garment in garments where garment.isWorn { garment.isWorn = false }
        try? context.save()
    }

    private func saveOutfit() {
        let name = outfitName.trimmingCharacters(in: .whitespacesAndNewlines)
        outfitName = ""
        guard !name.isEmpty, !wornGarments.isEmpty else { return }

        context.insert(Outfit(name: name, garments: wornGarments))
        try? context.save()
    }

    private func wear(_ outfit: Outfit) {
        undress()
        for garment in outfit.garments { garment.isWorn = true }
        try? context.save()
    }

}
