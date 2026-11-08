import SwiftData
import SwiftUI
import TreeCenterData

// La estantería.
//
// El giro de las tapas no lleva motor 3D: es `scrollTransition` más
// `rotation3DEffect` sobre un scroll horizontal normal. Va a 120 Hz y es una
// fracción del trabajo que costaría lo mismo en SceneKit.

struct FoodShelfView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \RecipeBook.order) private var books: [RecipeBook]
    @Query private var meals: [MealEntry]

    @State private var centred: PersistentIdentifier?
    @State private var creatingBook = false
    @State private var newBookName = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Alimentación", back: { dismiss() }) {
                Button { creatingBook = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Nuevo libro")
            }

            if books.isEmpty {
                emptyShelf
            } else {
                shelf
            }
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if centred == nil { centred = books.first?.persistentModelID } }
        .alert("Nuevo libro", isPresented: $creatingBook) {
            TextField("Nombre", text: $newBookName)
            Button("Cancelar", role: .cancel) { newBookName = "" }
            Button("Crear") { createBook() }
        } message: {
            Text("Recetas, básicos, suplementos… lo que quieras separar.")
        }
    }

    // MARK: - Estantería

    private var shelf: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(books) { book in
                        BookCover(book: book)
                            .containerRelativeFrame(.horizontal, count: 5, span: 3, spacing: 14)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .rotation3DEffect(.degrees(phase.value * -30),
                                                      axis: (x: 0, y: 1, z: 0),
                                                      perspective: 0.5)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.84)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centred)
            .scrollIndicators(.hidden)
            .frame(height: 300)

            shelfLine

            Spacer(minLength: 14)

            dots

            Spacer(minLength: 14)

            if let book = centredBook {
                VStack(spacing: 14) {
                    lastEntryCard
                    NavigationLink {
                        RecipeBookView(book: book)
                    } label: {
                        Text("Abrir libro")
                            .font(TCFont.font(15, .semibold))
                            .foregroundStyle(TCColor.onMoss)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(TCColor.moss)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    shortcuts
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 16)
            }
        }
    }

    /// La balda. Una línea que se desvanece por los bordes basta para que el
    /// libro parezca apoyado en algo en vez de flotar.
    private var shelfLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [TCColor.line.opacity(0), TCColor.line, TCColor.line.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 28)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(books) { book in
                let active = book.persistentModelID == centred
                Capsule()
                    .fill(active ? TCColor.moss : TCColor.track)
                    .frame(width: active ? 16 : 4, height: 4)
            }
        }
        .animation(.easeOut(duration: 0.2), value: centred)
    }

    private var centredBook: RecipeBook? {
        books.first { $0.persistentModelID == centred } ?? books.first
    }

    private var lastEntryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("ÚLTIMA COMIDA").tcLabel()
                Text(lastMeal?.name ?? "Nada apuntado hoy").tcRow()
            }
            Spacer(minLength: 8)
            if let lastMeal {
                Text("\(lastMeal.kcal) kcal")
                    .font(TCFont.font(12))
                    .monospacedDigit()
                    .foregroundStyle(TCColor.textSoft)
            }
        }
        .tcCard(padding: 15)
    }

    private var lastMeal: MealEntry? {
        meals.filter { Calendar.current.isDateInToday($0.date) }
            .max { $0.date < $1.date }
    }

    private var shortcuts: some View {
        HStack(spacing: 10) {
            Button {} label: {
                Label("Foto", systemImage: "camera")
                    .font(TCFont.font(13, .medium))
            }
            .buttonStyle(TCGhostButtonStyle())

            Button {} label: {
                Label("Buscar", systemImage: "magnifyingglass")
                    .font(TCFont.font(13, .medium))
            }
            .buttonStyle(TCGhostButtonStyle())
        }
    }

    // MARK: - Estantería vacía

    private var emptyShelf: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(TCColor.textFaint)
            Text("La estantería está vacía").tcSection()
            Text("Un libro por tema: recetas, básicos, suplementos. Dentro van los capítulos y las fichas.")
                .tcBody()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button("Crear el primero") { creatingBook = true }
                .buttonStyle(TCPrimaryButtonStyle())
                .padding(.horizontal, 60)
                .padding(.top, 6)
            Spacer()
            Spacer()
        }
    }

    private func createBook() {
        let name = newBookName.trimmingCharacters(in: .whitespacesAndNewlines)
        newBookName = ""
        guard !name.isEmpty else { return }

        let palette = PaletteColor.allCases
        let book = RecipeBook(name: name,
                              color: palette[books.count % palette.count],
                              order: books.count)
        context.insert(book)
        try? context.save()
        centred = book.persistentModelID
    }
}

// MARK: - La tapa

struct BookCover: View {
    let book: RecipeBook

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TCColor.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(TCColor.line, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 22, x: -10, y: 14)

            // El lomo: la franja que hace que esto sea un libro y no una tarjeta.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(spineColor)
                    .frame(width: 9)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "leaf")
                    .font(.system(size: 26, weight: .ultraLight))
                    .foregroundStyle(spineColor)
                Spacer(minLength: 0)
                Text(book.name)
                    .font(TCFont.font(22, .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(TCColor.text)
                    .lineLimit(2)
                Text(countLine)
                    .tcMicro()
                    .padding(.top, 4)
            }
            .padding(.leading, 22)
            .padding([.top, .trailing, .bottom], 18)
        }
        .aspectRatio(0.69, contentMode: .fit)
        .padding(.vertical, 8)
    }

    private var countLine: String {
        let recipes = book.recipeCount
        let chapters = book.chapters.count
        if recipes == 0 { return chapters == 0 ? "vacío" : "\(chapters) capítulos · sin fichas" }
        return "\(recipes) fichas · \(chapters) capítulos"
    }

    private var spineColor: Color {
        switch book.color {
        case .moss: return TCColor.moss
        case .blue: return TCColor.blue
        case .sand: return TCColor.sand
        case .clay: return TCColor.clay
        case .lilac: return TCColor.lilac
        case .neutral: return TCColor.textSoft
        }
    }
}
