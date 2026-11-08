import SwiftData
import SwiftUI
import TreeCenterData

// Biblioteca. Libros de lectura, separados de los libros de recetas: mismo
// lenguaje visual, datos distintos.
//
// El ancho de cada lomo lo dan las páginas (`Book.spineWidth`). Es un detalle
// pequeño que hace que el estante parezca un estante y no una fila de barras.

struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Book.title) private var books: [Book]

    @State private var adding = false
    @State private var highlighting: Book?

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Biblioteca", subtitle: subtitle, back: { dismiss() }) {
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Añadir libro")
            }

            ScrollView {
                VStack(spacing: 20) {
                    readingBlock
                    shelfBlock
                    highlightsBlock
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) { BookEditor() }
        .sheet(item: $highlighting) { book in HighlightEditor(book: book) }
    }

    private var subtitle: String? {
        books.isEmpty ? nil : "\(books.count) libros"
    }

    private var reading: Book? {
        books.first { $0.readingNow } ?? books.first { $0.currentPage > 0 && $0.finishedAt == nil }
    }

    // MARK: - Leyendo ahora

    @ViewBuilder
    private var readingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Leyendo ahora")

            if let reading {
                HStack(spacing: 15) {
                    Spine(book: reading, height: 92, flat: true)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(reading.title)
                            .font(TCFont.font(15, .medium))
                            .foregroundStyle(TCColor.text)
                            .lineLimit(2)
                        if !reading.author.isEmpty { Text(reading.author).tcMicro() }
                        TCProgressBar(value: reading.progress, tint: reading.color.swiftUI)
                        HStack {
                            Text("página \(reading.currentPage) de \(reading.pages)")
                                .tcMicro()
                                .monospacedDigit()
                            Spacer(minLength: 6)
                            Stepper("", value: Binding(
                                get: { reading.currentPage },
                                set: { reading.currentPage = min(reading.pages, max(0, $0)); try? context.save() }
                            ), in: 0...max(1, reading.pages), step: 5)
                            .labelsHidden()
                            .scaleEffect(0.8)
                            .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
                .tcCard(padding: 16)
            } else {
                Text("No hay ningún libro empezado.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            }
        }
    }

    // MARK: - Estante

    private var shelfBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Estante", trailing: books.isEmpty ? nil : "toca para marcar lectura")

            VStack(spacing: 10) {
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(books) { book in
                            Button { startReading(book) } label: {
                                Spine(book: book, height: 118 + CGFloat(book.pages % 5) * 3, flat: false)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Subrayar algo") { highlighting = book }
                                Button("Borrar", role: .destructive) {
                                    context.delete(book); try? context.save()
                                }
                            }
                        }

                        if books.isEmpty {
                            Text("El estante está vacío.")
                                .tcMicro()
                                .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)

                Rectangle().fill(TCColor.lineStrong).frame(height: 1)

                Text("el ancho del lomo lo dan las páginas")
                    .font(TCFont.font(10))
                    .foregroundStyle(TCColor.textMicro)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tcCard(padding: 14, sunken: true)
        }
    }

    private func startReading(_ book: Book) {
        for other in books where other.readingNow { other.readingNow = false }
        book.readingNow = true
        try? context.save()
    }

    // MARK: - Subrayados

    private var allHighlights: [Highlight] {
        books.flatMap(\.highlights).sorted { $0.createdAt > $1.createdAt }
    }

    private var highlightsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Subrayados")

            if allHighlights.isEmpty {
                Text("Mantén pulsado un lomo para subrayar una frase.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(allHighlights.prefix(6)) { item in
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(alignment: .top, spacing: 12) {
                                Capsule().fill(TCColor.moss).frame(width: 3)
                                Text("«\(item.text)»")
                                    .font(TCFont.font(13.5))
                                    .foregroundStyle(TCColor.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack {
                                Text("\(item.book?.title ?? "—") · pág. \(item.page)")
                                    .tcMicro()
                                Spacer(minLength: 8)
                                Button { sendToNotes(item) } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(item.sentToNotes ? "En Formación" : "Mandar a una nota")
                                            .font(TCFont.font(11))
                                    }
                                    .foregroundStyle(item.sentToNotes ? TCColor.textMicro : TCColor.moss)
                                }
                                .buttonStyle(.plain)
                                .disabled(item.sentToNotes)
                            }
                        }
                        .tcCard(padding: 16)
                    }
                }
            }
        }
    }

    /// El subrayado llega a Formación con su origen puesto. Eso es lo que hace
    /// que una nota suelta se pueda rastrear seis meses después.
    private func sendToNotes(_ highlight: Highlight) {
        let topicName = "Lecturas"
        let descriptor = FetchDescriptor<Topic>()
        let existing = (try? context.fetch(descriptor))?.first { $0.name == topicName }

        let topic: Topic
        if let existing {
            topic = existing
        } else {
            topic = Topic(name: topicName, order: 99)
            context.insert(topic)
        }

        let note = StudyNote(
            title: highlight.book?.title ?? "Subrayado",
            body: highlight.text,
            source: "Biblioteca · \(highlight.book?.title ?? "—") p. \(highlight.page)"
        )
        context.insert(note)
        note.topic = topic
        highlight.sentToNotes = true
        try? context.save()
    }
}

// MARK: - El lomo

private struct Spine: View {
    let book: Book
    let height: CGFloat
    let flat: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(TCColor.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(TCColor.line, lineWidth: 1)
                )

            HStack(spacing: 0) {
                Rectangle().fill(book.color.swiftUI).frame(width: 3)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            if flat {
                Image(systemName: "book.closed")
                    .font(.system(size: 20, weight: .ultraLight))
                    .foregroundStyle(book.color.swiftUI)
            } else {
                Text(book.title)
                    .font(TCFont.font(8.5))
                    .foregroundStyle(book.readingNow ? TCColor.text : TCColor.textSoft)
                    .lineLimit(1)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .frame(width: width - 8, height: height - 16)
                    .clipped()
            }
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(book.readingNow ? book.color.swiftUI : Color.clear, lineWidth: 1.5)
        )
    }

    private var width: CGFloat { flat ? 58 : book.spineWidth }
}

// MARK: - Editores

private struct BookEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var author = ""
    @State private var pages = 200

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

            VStack(spacing: 14) {
                field("Título", text: $title, placeholder: "El hombre en busca de sentido")
                field("Autor", text: $author, placeholder: "Viktor Frankl")

                VStack(alignment: .leading, spacing: 9) {
                    TCSectionLabel(text: "Páginas", trailing: "marcan el ancho del lomo")
                    HStack {
                        TextField("200", value: $pages, format: .number)
                            .keyboardType(.numberPad)
                            .font(TCFont.font(15))
                            .monospacedDigit()
                            .foregroundStyle(TCColor.text)
                        Stepper("", value: $pages, in: 1...3000, step: 20).labelsHidden()
                    }
                    .tcCard(padding: 14, radius: TCRadius.control)
                }
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 18)

            Spacer()
        }
        .background(TCColor.bg)
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

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        let palette = PaletteColor.allCases
        context.insert(Book(title: title.trimmingCharacters(in: .whitespaces),
                            author: author.trimmingCharacters(in: .whitespaces),
                            pages: max(1, pages),
                            color: palette[abs(title.hashValue) % palette.count]))
        try? context.save()
        dismiss()
    }
}

private struct HighlightEditor: View {
    let book: Book

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var page = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .font(TCFont.font(14)).foregroundStyle(TCColor.textSoft)
                Spacer()
                Text("Subrayar").font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
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
                VStack(alignment: .leading, spacing: 9) {
                    TCSectionLabel(text: "Frase", trailing: book.title)
                    TextField("Lo que te hizo parar", text: $text, axis: .vertical)
                        .font(TCFont.font(14))
                        .foregroundStyle(TCColor.text)
                        .lineLimit(3...8)
                        .tcCard(padding: 14, radius: TCRadius.control)
                }

                VStack(alignment: .leading, spacing: 9) {
                    TCSectionLabel(text: "Página")
                    HStack {
                        TextField("1", value: $page, format: .number)
                            .keyboardType(.numberPad)
                            .font(TCFont.font(15))
                            .monospacedDigit()
                            .foregroundStyle(TCColor.text)
                        Stepper("", value: $page, in: 1...max(1, book.pages)).labelsHidden()
                    }
                    .tcCard(padding: 14, radius: TCRadius.control)
                }
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 18)

            Spacer()
        }
        .background(TCColor.bg)
    }

    private var canSave: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        let highlight = Highlight(text: text.trimmingCharacters(in: .whitespaces), page: page)
        context.insert(highlight)
        highlight.book = book
        try? context.save()
        dismiss()
    }
}
