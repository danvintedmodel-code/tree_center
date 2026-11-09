import SwiftData
import SwiftUI
import TreeCenterData

// El libro abierto: capítulos a la izquierda, fichas a la derecha.
// Los tres hairlines del canto derecho son lo único que hace falta para que
// esto se lea como un libro y no como dos listas pegadas.

struct RecipeBookView: View {
    let book: RecipeBook

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var selectedChapter: PersistentIdentifier?
    @State private var addingChapter = false
    @State private var newChapterName = ""
    @State private var editingRecipe: Recipe?
    @State private var creatingRecipe = false

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: book.name,
                           subtitle: "\(book.recipeCount) fichas",
                           back: { dismiss() })

            ScrollView {
                VStack(spacing: 14) {
                    spread
                    pager
                    bottomButtons
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if selectedChapter == nil { selectedChapter = book.orderedChapters.first?.persistentModelID } }
        .alert("Nuevo capítulo", isPresented: $addingChapter) {
            TextField("Nombre", text: $newChapterName)
            Button("Cancelar", role: .cancel) { newChapterName = "" }
            Button("Crear") { createChapter() }
        }
        .sheet(isPresented: $creatingRecipe) {
            RecipeEditorView(book: book, chapter: chapter, recipe: nil)
        }
        .sheet(item: $editingRecipe) { recipe in
            RecipeEditorView(book: book, chapter: recipe.chapter, recipe: recipe)
        }
    }

    private var chapter: Chapter? {
        book.orderedChapters.first { $0.persistentModelID == selectedChapter }
            ?? book.orderedChapters.first
    }

    // MARK: - La doble página

    private var spread: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                chaptersColumn
                    .frame(width: 124)

                Rectangle()
                    .fill(TCColor.line)
                    .frame(width: 1)

                recipesColumn
                    .frame(maxWidth: .infinity)
            }
            .frame(minHeight: 420, alignment: .top)
            .background(TCColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TCColor.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 24, y: 12)

            // El canto: las páginas que quedan por pasar.
            HStack(spacing: 3) {
                Rectangle().fill(TCColor.line).frame(width: 1).padding(.vertical, 26)
                Rectangle().fill(TCColor.line.opacity(0.6)).frame(width: 1).padding(.vertical, 20)
                Rectangle().fill(TCColor.line.opacity(0.3)).frame(width: 1).padding(.vertical, 14)
            }
            .padding(.trailing, 2)
            .allowsHitTesting(false)
        }
    }

    private var chaptersColumn: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("CAPÍTULOS").tcLabel()

            ForEach(book.orderedChapters) { item in
                Button {
                    selectedChapter = item.persistentModelID
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.persistentModelID == chapter?.persistentModelID
                                  ? TCColor.moss : Color.clear)
                            .frame(width: 5, height: 5)
                        Text(item.name)
                            .font(TCFont.font(13, item.persistentModelID == chapter?.persistentModelID ? .medium : .regular))
                            .foregroundStyle(item.persistentModelID == chapter?.persistentModelID
                                             ? TCColor.moss : TCColor.textSoft)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 10)

            Button { addingChapter = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                    Text("Capítulo").font(TCFont.font(11))
                }
                .foregroundStyle(TCColor.textMicro)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var recipesColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text((chapter?.name ?? "Sin capítulo").uppercased()).tcLabel()
                Spacer(minLength: 6)
                Text("\(chapter?.recipes.count ?? 0)").tcMicro()
            }

            if let chapter, !chapter.recipes.isEmpty {
                ForEach(chapter.orderedRecipes) { recipe in
                    NavigationLink {
                        RecipeView(recipe: recipe)
                    } label: {
                        recipeRow(recipe)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Este capítulo está vacío.")
                    .tcMicro()
                    .padding(.vertical, 6)
            }

            Spacer(minLength: 10)

            Button { creatingRecipe = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                    Text("Ficha").font(TCFont.font(11))
                }
                .foregroundStyle(TCColor.textMicro)
            }
            .buttonStyle(.plain)
            .disabled(chapter == nil)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func recipeRow(_ recipe: Recipe) -> some View {
        HStack(spacing: 11) {
            PhotoThumb(data: recipe.image, side: 42, radius: 12, symbol: "fork.knife")

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(TCFont.font(13, .medium))
                    .foregroundStyle(TCColor.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(recipe.kcal) kcal · \(recipe.proteinG) P")
                    .font(TCFont.font(11))
                    .monospacedDigit()
                    .foregroundStyle(TCColor.textSoft)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Pie

    private var pager: some View {
        HStack(spacing: 16) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(canStep(-1) ? TCColor.text : TCColor.textFaint)
            }
            .disabled(!canStep(-1))

            Text("\(currentIndex + 1) / \(max(1, book.chapters.count))")
                .font(TCFont.font(12))
                .monospacedDigit()
                .foregroundStyle(TCColor.textSoft)

            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(canStep(1) ? TCColor.text : TCColor.textFaint)
            }
            .disabled(!canStep(1))
        }
        .buttonStyle(.plain)
    }

    private var currentIndex: Int {
        book.orderedChapters.firstIndex { $0.persistentModelID == chapter?.persistentModelID } ?? 0
    }

    private func canStep(_ delta: Int) -> Bool {
        let next = currentIndex + delta
        return next >= 0 && next < book.orderedChapters.count
    }

    private func step(_ delta: Int) {
        guard canStep(delta) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            selectedChapter = book.orderedChapters[currentIndex + delta].persistentModelID
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 10) {
            Button {} label: {
                Label("Cámara", systemImage: "camera").font(TCFont.font(13, .medium))
            }
            .buttonStyle(TCGhostButtonStyle())

            Button {} label: {
                Label("Adjuntar", systemImage: "photo").font(TCFont.font(13, .medium))
            }
            .buttonStyle(TCGhostButtonStyle())
        }
    }

    // MARK: - Acciones

    private func createChapter() {
        let name = newChapterName.trimmingCharacters(in: .whitespacesAndNewlines)
        newChapterName = ""
        guard !name.isEmpty else { return }

        let chapter = Chapter(name: name, order: book.chapters.count)
        context.insert(chapter)
        chapter.book = book
        try? context.save()
        selectedChapter = chapter.persistentModelID
    }
}
