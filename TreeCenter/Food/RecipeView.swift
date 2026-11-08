import SwiftData
import SwiftUI
import TreeCenterData

// La ficha. Lo importante de esta pantalla es el botón de abajo: apuntar que te
// has comido esto tiene que costar un toque desde aquí.

struct RecipeView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var editing = false
    @State private var added = false

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: recipe.name, subtitle: breadcrumb, back: { dismiss() }) {
                Button("Editar") { editing = true }
                    .font(TCFont.font(14))
                    .foregroundStyle(TCColor.textSoft)
            }

            ScrollView {
                VStack(spacing: 18) {
                    imageCard
                    macros
                    ingredients
                    steps
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            footer
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editing) {
            RecipeEditorView(book: recipe.chapter?.book, chapter: recipe.chapter, recipe: recipe)
        }
    }

    private var breadcrumb: String {
        [recipe.chapter?.book?.name, recipe.chapter?.name]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    // MARK: - Imagen

    private var imageCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(TCColor.cardSunken)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(TCColor.line, lineWidth: 1)
                )

            Text("PNG · FONDO RECORTADO")
                .tcLabel()
                .padding(16)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(TCColor.textFaint)
                    Spacer()
                }
                Spacer()
            }

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Spacer()
                    roundButton("camera", label: "Hacer foto")
                    roundButton("photo", label: "Elegir de la galería")
                }
                .padding(14)
            }
        }
        .frame(height: 220)
    }

    private func roundButton(_ symbol: String, label: String) -> some View {
        Button {} label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(TCColor.text)
                .frame(width: 40, height: 40)
                .background(TCColor.bg)
                .clipShape(Circle())
                .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Macros

    private var macros: some View {
        HStack(spacing: 8) {
            macroTile("KCAL", recipe.kcal)
            macroTile("PROT", recipe.proteinG)
            macroTile("HIDR", recipe.carbsG)
            macroTile("GRAS", recipe.fatG)
        }
    }

    private func macroTile(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(TCFont.font(9.5, .semibold))
                .tracking(1)
                .foregroundStyle(TCColor.textMicro)
            Text("\(value)")
                .font(TCFont.font(17, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.text)
        }
        .frame(maxWidth: .infinity)
        .tcCard(padding: 11, radius: TCRadius.control)
    }

    // MARK: - Ingredientes y pasos

    @ViewBuilder
    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Ingredientes")

            if recipe.ingredients.isEmpty {
                Text("Sin ingredientes apuntados.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedIngredients.enumerated()), id: \.element.persistentModelID) { index, item in
                        HStack {
                            Text(item.name).font(TCFont.font(13.5)).foregroundStyle(TCColor.text)
                            Spacer(minLength: 8)
                            Text(item.amount)
                                .font(TCFont.font(12.5))
                                .monospacedDigit()
                                .foregroundStyle(TCColor.textSoft)
                        }
                        .padding(.vertical, 10)

                        if index < sortedIngredients.count - 1 { Divider().overlay(TCColor.line) }
                    }
                }
                .tcCard(padding: 14)
            }
        }
    }

    private var sortedIngredients: [Ingredient] {
        recipe.ingredients.sorted { $0.order < $1.order }
    }

    @ViewBuilder
    private var steps: some View {
        if !recipe.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text("PREPARACIÓN").tcLabel()
                Text(recipe.steps)
                    .font(TCFont.font(12.5))
                    .foregroundStyle(TCColor.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .tcCard(padding: 16, sunken: true)
        }
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: 8) {
            Button(added ? "Apuntado" : "Añadir al día de hoy") { addToToday() }
                .buttonStyle(TCPrimaryButtonStyle())
                .disabled(added)

            if added {
                Text("Sumado a lo de hoy.").tcMicro()
            }
        }
        .padding(.horizontal, TCSpace.gutter)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(TCColor.bg)
        .animation(.easeOut(duration: 0.2), value: added)
    }

    /// Copia los macros en vez de apuntar a la receta: si mañana la editas, lo
    /// que comiste hoy no debe cambiar contigo.
    private func addToToday() {
        context.insert(MealEntry(copying: recipe))
        try? context.save()
        added = true

        // Se vuelve a habilitar a los tres segundos: a veces repites plato,
        // pero dos toques seguidos sin querer no deberían contar doble.
        Task {
            try? await Task.sleep(for: .seconds(3))
            added = false
        }
    }
}
