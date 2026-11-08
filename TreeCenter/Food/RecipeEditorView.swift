import SwiftData
import SwiftUI
import TreeCenterData

// Crear o editar una ficha.
//
// Se edita sobre una copia en memoria y solo se vuelca al modelo al guardar:
// así cancelar es cancelar de verdad, y no deja a medias una receta con el
// nombre cambiado y los macros viejos.

struct RecipeEditorView: View {
    let book: RecipeBook?
    let chapter: Chapter?
    let recipe: Recipe?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var kcal = 0
    @State private var protein = 0
    @State private var carbs = 0
    @State private var fat = 0
    @State private var steps = ""
    @State private var rows: [Row] = []
    @State private var targetChapter: PersistentIdentifier?

    private struct Row: Identifiable {
        let id = UUID()
        var name: String = ""
        var amount: String = ""
    }

    private var isNew: Bool { recipe == nil }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 18) {
                    nameField
                    chapterPicker
                    macroFields
                    ingredientRows
                    stepsField
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            Button("Cancelar") { dismiss() }
                .font(TCFont.font(14))
                .foregroundStyle(TCColor.textSoft)

            Spacer()
            Text(isNew ? "Nueva ficha" : "Editar ficha")
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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Campos

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "Nombre")
            TextField("Tortilla de avena", text: $name)
                .font(TCFont.font(15))
                .foregroundStyle(TCColor.text)
                .tcCard(padding: 14, radius: TCRadius.control)
        }
    }

    private var chapters: [Chapter] { book?.orderedChapters ?? [] }

    @ViewBuilder
    private var chapterPicker: some View {
        if chapters.count > 1 {
            VStack(alignment: .leading, spacing: 9) {
                TCSectionLabel(text: "Capítulo")
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(chapters) { item in
                            Button {
                                targetChapter = item.persistentModelID
                            } label: {
                                TCChip(text: item.name,
                                       selected: item.persistentModelID == targetChapter)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var macroFields: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "Macros", trailing: "por ración")
            HStack(spacing: 8) {
                macroField("KCAL", value: $kcal)
                macroField("PROT", value: $protein)
                macroField("HIDR", value: $carbs)
                macroField("GRAS", value: $fat)
            }
        }
    }

    private func macroField(_ label: String, value: Binding<Int>) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(TCFont.font(9.5, .semibold))
                .tracking(1)
                .foregroundStyle(TCColor.textMicro)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(TCFont.font(17, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.text)
        }
        .frame(maxWidth: .infinity)
        .tcCard(padding: 11, radius: TCRadius.control)
    }

    private var ingredientRows: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "Ingredientes")

            VStack(spacing: 0) {
                ForEach($rows) { $row in
                    HStack(spacing: 10) {
                        TextField("Avena", text: $row.name)
                            .font(TCFont.font(13.5))
                            .foregroundStyle(TCColor.text)

                        TextField("60 g", text: $row.amount)
                            .font(TCFont.font(12.5))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(TCColor.textSoft)
                            .frame(width: 76)

                        Button {
                            rows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 15, weight: .light))
                                .foregroundStyle(TCColor.textFaint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quitar ingrediente")
                    }
                    .padding(.vertical, 9)

                    Divider().overlay(TCColor.line)
                }

                Button {
                    rows.append(Row())
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        Text("Añadir ingrediente").font(TCFont.font(12.5))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(TCColor.textMicro)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .tcCard(padding: 14)
        }
    }

    private var stepsField: some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: "Preparación")
            TextEditor(text: $steps)
                .font(TCFont.font(13))
                .foregroundStyle(TCColor.text)
                .scrollContentBackground(.hidden)
                .frame(height: 110)
                .tcCard(padding: 12, radius: TCRadius.control)
        }
    }

    // MARK: - Cargar y guardar

    private func load() {
        targetChapter = (recipe?.chapter ?? chapter)?.persistentModelID

        guard let recipe else {
            if rows.isEmpty { rows = [Row()] }
            return
        }

        name = recipe.name
        kcal = recipe.kcal
        protein = recipe.proteinG
        carbs = recipe.carbsG
        fat = recipe.fatG
        steps = recipe.steps
        rows = recipe.ingredients
            .sorted { $0.order < $1.order }
            .map { Row(name: $0.name, amount: $0.amount) }
        if rows.isEmpty { rows = [Row()] }
    }

    private func save() {
        let target = (book?.orderedChapters.first { $0.persistentModelID == targetChapter })
            ?? recipe?.chapter
            ?? chapter

        let model: Recipe
        if let recipe {
            model = recipe
        } else {
            model = Recipe(order: target?.recipes.count ?? 0)
            context.insert(model)
        }

        model.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        model.kcal = kcal
        model.proteinG = protein
        model.carbsG = carbs
        model.fatG = fat
        model.steps = steps
        model.chapter = target

        // Los ingredientes se rehacen enteros: son pocos y así no hay que casar
        // cuáles se han editado, cuáles son nuevos y cuáles ha quitado.
        for old in model.ingredients { context.delete(old) }
        for (index, row) in rows.enumerated() where !row.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let ingredient = Ingredient(name: row.name.trimmingCharacters(in: .whitespaces),
                                        amount: row.amount.trimmingCharacters(in: .whitespaces),
                                        order: index)
            context.insert(ingredient)
            ingredient.recipe = model
        }

        try? context.save()
        dismiss()
    }
}
