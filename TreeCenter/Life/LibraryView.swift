import SwiftData
import SwiftUI
import TreeCenterData

// Biblioteca: una balda por categoría, apiladas hacia abajo según se crean.
// Cada balda tiene a la derecha un botón que despliega sus datos. Los libros se
// ven de frente, con su tapa, de pie sobre la balda.

struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Shelf.order) private var shelves: [Shelf]
    @Query(sort: \Book.addedAt) private var books: [Book]

    @State private var open: Set<String> = []
    @State private var addingShelf = false
    @State private var shelfName = ""
    @State private var addingBook = false

    private var unshelved: [Book] { books.filter { $0.shelf == nil } }

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Biblioteca",
                           subtitle: books.isEmpty ? nil : "\(books.count) libros en \(shelves.count) baldas",
                           back: { dismiss() }) {
                Button { addingBook = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Añadir libro")
            }

            ScrollView {
                VStack(spacing: 24) {
                    if shelves.isEmpty && books.isEmpty {
                        VStack(spacing: 8) {
                            Text("La estantería está vacía").tcRow()
                            Text("Crea una balda por categoría y añade libros escaneando su código de barras.")
                                .tcMicro()
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .tcCard(padding: 16, sunken: true)
                    }

                    ForEach(shelves) { shelf in
                        ShelfRow(title: shelf.name, books: shelf.orderedBooks,
                                 isOpen: open.contains(key(shelf)),
                                 toggle: { toggle(key(shelf)) })
                            .contextMenu {
                                Button("Borrar la balda (los libros se quedan)", role: .destructive) {
                                    context.delete(shelf)
                                    try? context.save()
                                }
                            }
                    }

                    if !unshelved.isEmpty {
                        ShelfRow(title: "Sin balda", books: unshelved,
                                 isOpen: open.contains("sin-balda"),
                                 toggle: { toggle("sin-balda") })
                    }

                    Button("Nueva balda") { addingShelf = true }
                        .buttonStyle(TCGhostButtonStyle(dashed: true))

                    Text("Cada balda es una categoría, y las nuevas van debajo. Al añadir un libro, su código de barras trae la tapa de verdad.")
                        .tcMicro()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $addingBook) {
            BookEditor(shelves: shelves)
        }
        .alert("Nueva balda", isPresented: $addingShelf) {
            TextField("Ensayo, Novela, Negocio…", text: $shelfName)
            Button("Cancelar", role: .cancel) { shelfName = "" }
            Button("Crear") { createShelf() }
        }
    }

    private func key(_ shelf: Shelf) -> String { String(describing: shelf.persistentModelID) }

    private func toggle(_ key: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            if open.contains(key) { open.remove(key) } else { open.insert(key) }
        }
    }

    private func createShelf() {
        let name = shelfName.trimmingCharacters(in: .whitespacesAndNewlines)
        shelfName = ""
        guard !name.isEmpty else { return }
        context.insert(Shelf(name: name, order: (shelves.map(\.order).max() ?? -1) + 1))
        try? context.save()
    }
}

// MARK: - Una balda

private struct ShelfRow: View {
    let title: String
    let books: [Book]
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title.uppercased()).tcLabel()
                Spacer()
                Text("\(books.count)").tcMicro()
                Button(action: toggle) {
                    HStack(spacing: 5) {
                        Text("Info")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .font(TCFont.font(11))
                    .foregroundStyle(isOpen ? TCColor.moss : TCColor.textSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isOpen ? TCColor.mossWell : Color.clear)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(isOpen ? TCColor.moss : TCColor.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOpen ? "Ocultar los datos de \(title)" : "Ver los datos de \(title)")
            }

            VStack(spacing: 0) {
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 10) {
                        if books.isEmpty {
                            Text("Balda vacía.")
                                .tcMicro()
                                .frame(height: 100)
                        }
                        ForEach(books) { book in
                            NavigationLink { BookDetailView(book: book) } label: {
                                let height = 92 + min(16, CGFloat(book.pages) / 45)
                                BookCover(book: book, width: (height * 0.66).rounded(), height: height.rounded())
                                    .shadow(color: .black.opacity(0.35), radius: 5, y: 5)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(book.title)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
                .scrollIndicators(.hidden)

                // La balda: una tabla con su sombra debajo.
                RoundedRectangle(cornerRadius: 2)
                    .fill(TCColor.lineStrong)
                    .frame(height: 5)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 6)
            }

            if isOpen { info.transition(.opacity.combined(with: .move(edge: .top))) }
        }
    }

    private var info: some View {
        let read = books.filter(\.isFinished).count
        let pages = books.reduce(0) { $0 + $1.pages }
        let average = books.isEmpty ? 0 : books.reduce(0.0) { $0 + $1.progress } / Double(books.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                infoTile("LEÍDOS", "\(read)/\(books.count)")
                infoTile("PÁGINAS", pages.formatted(.number.grouping(.automatic)))
                infoTile("MEDIA", "\(Int((average * 100).rounded()))%")
            }
            ForEach(books) { book in
                HStack {
                    Text(book.title).font(TCFont.font(13)).foregroundStyle(TCColor.text).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(book.isFinished ? "leído" : (book.currentPage > 0 ? "\(Int((book.progress * 100).rounded()))%" : "sin empezar"))
                        .tcMicro()
                }
            }
        }
        .tcCard(padding: 14)
    }

    private func infoTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(TCFont.font(9, .semibold)).tracking(1).foregroundStyle(TCColor.textMicro)
            Text(value).font(TCFont.font(15, .semibold)).monospacedDigit().foregroundStyle(TCColor.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(TCColor.well)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Un libro

struct BookDetailView: View {
    @Bindable var book: Book

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Shelf.order) private var shelves: [Shelf]

    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: book.title, subtitle: book.author.isEmpty ? nil : book.author, back: { dismiss() })

            ScrollView {
                VStack(spacing: 18) {
                    BookCover(book: book, width: 150, height: 225)
                        .shadow(color: .black.opacity(0.45), radius: 16, y: 14)
                        .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("PROGRESO").tcLabel()
                            Spacer()
                            Text("\(book.currentPage) / \(book.pages)").tcNumber(13)
                        }
                        TCProgressBar(value: book.progress)
                        HStack(spacing: 7) {
                            pageButton("−10", -10)
                            pageButton("+10", 10)
                            pageButton("+20", 20)
                            pageButton("Terminado", book.pages)
                        }
                    }
                    .tcCard(padding: 16)

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Balda")
                        ScrollView(.horizontal) {
                            HStack(spacing: 7) {
                                ForEach(shelves) { shelf in
                                    Button {
                                        book.shelf = shelf
                                        try? context.save()
                                    } label: {
                                        TCChip(text: shelf.name, selected: book.shelf?.persistentModelID == shelf.persistentModelID)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Tapa", trailing: book.isbn.isEmpty ? nil : "ISBN \(book.isbn)")
                        PhotoWell(data: $book.cover, height: 180, symbol: "book.closed",
                                  hint: "Si no salió sola, hazle una foto", mode: .fit)
                    }

                    Button("Quitar el libro") { confirmingDelete = true }
                        .font(TCFont.font(13))
                        .foregroundStyle(TCColor.clay)
                        .padding(.top, 6)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("¿Quitar «\(book.title)»?", isPresented: $confirmingDelete) {
            Button("Cancelar", role: .cancel) {}
            Button("Quitar", role: .destructive) {
                context.delete(book)
                try? context.save()
                dismiss()
            }
        }
    }

    private func pageButton(_ title: String, _ delta: Int) -> some View {
        Button {
            book.read(delta)
            try? context.save()
        } label: {
            TCChip(text: title)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Añadir un libro

struct BookEditor: View {
    let shelves: [Shelf]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var isbn = ""
    @State private var title = ""
    @State private var author = ""
    @State private var pages = ""
    @State private var cover: Data?
    @State private var shelf: Shelf?
    @State private var scanning = false
    @State private var status: String?
    @State private var searching = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .font(TCFont.font(14)).foregroundStyle(TCColor.textSoft)
                Spacer()
                Text("Nuevo libro").font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
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
                VStack(spacing: 16) {
                    if BarcodeScanner.isAvailable {
                        Button { scanning = true } label: {
                            Label("Escanear el código de barras", systemImage: "barcode.viewfinder")
                        }
                        .buttonStyle(TCPrimaryButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "ISBN", trailing: "el número del código de barras")
                        HStack(spacing: 8) {
                            TextField("9788499890944", text: $isbn)
                                .keyboardType(.numbersAndPunctuation)
                                .font(TCFont.font(15))
                                .monospacedDigit()
                                .foregroundStyle(TCColor.text)
                                .tcCard(padding: 14, radius: TCRadius.control)
                            Button(searching ? "Buscando…" : "Buscar") { lookup() }
                                .buttonStyle(TCGhostButtonStyle())
                                .frame(width: 110)
                                .disabled(searching || BookLookup.clean(isbn).count < 10)
                        }
                        if let status {
                            Text(status).tcMicro().fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    field("Título", text: $title, placeholder: "Meditaciones")
                    field("Autor", text: $author, placeholder: "Marco Aurelio")
                    field("Páginas", text: $pages, placeholder: "180", numeric: true)

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Balda")
                        ScrollView(.horizontal) {
                            HStack(spacing: 7) {
                                Button { shelf = nil } label: { TCChip(text: "Sin balda", selected: shelf == nil) }
                                    .buttonStyle(.plain)
                                ForEach(shelves) { option in
                                    Button { shelf = option } label: {
                                        TCChip(text: option.name, selected: shelf?.persistentModelID == option.persistentModelID)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Tapa")
                        PhotoWell(data: $cover, height: 200, symbol: "book.closed",
                                  hint: "Sale sola al escanear, o hazle una foto", mode: .fit)
                    }
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(TCColor.bg)
        .onAppear { if shelf == nil { shelf = shelves.first } }
        .fullScreenCover(isPresented: $scanning) {
            BarcodeScanner { code in
                isbn = code
                lookup()
            }
            .ignoresSafeArea()
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            TCSectionLabel(text: label)
            TextField(placeholder, text: text)
                .keyboardType(numeric ? .numberPad : .default)
                .font(TCFont.font(15))
                .foregroundStyle(TCColor.text)
                .tcCard(padding: 14, radius: TCRadius.control)
        }
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private func lookup() {
        let code = BookLookup.clean(isbn)
        guard code.count >= 10 else { return }
        searching = true
        status = nil

        Task { @MainActor in
            let found = await BookLookup.find(isbn: code)
            searching = false

            guard let found else {
                status = "No está en Open Library, o no hay conexión. Rellénalo a mano y hazle una foto a la tapa."
                return
            }
            // Solo se rellena lo que esté vacío: si ya escribiste algo, manda lo tuyo.
            if title.isEmpty { title = found.title }
            if author.isEmpty { author = found.author }
            if pages.isEmpty, let count = found.pages { pages = String(count) }
            if cover == nil { cover = found.cover }
            status = found.cover == nil ? "Encontrado, pero sin tapa: puedes hacerle una foto." : "Encontrado, con su tapa."
        }
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // El color de la tapa dibujada sale del título, siempre el mismo para el
        // mismo libro. No `hashValue`: cambia en cada arranque, y su `abs` puede
        // desbordarse con el número más negativo.
        let palette = PaletteColor.allCases
        let seed = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 1_000_003 }
        let book = Book(title: name,
                        author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                        pages: max(1, Int(pages) ?? 200),
                        color: palette[seed % palette.count],
                        isbn: BookLookup.clean(isbn))
        book.cover = cover
        context.insert(book)
        book.shelf = shelf
        try? context.save()
        dismiss()
    }
}
