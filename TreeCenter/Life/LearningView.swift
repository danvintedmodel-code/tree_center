import SwiftData
import SwiftUI
import TreeCenterData

// Formación. Dos cosas distintas en una sección: lo que estás estudiando y lo
// que ya sabes. Un curso terminado no desaparece, se queda al 100 % como registro.

struct LearningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Topic.order) private var topics: [Topic]

    @State private var creatingCourse = false
    @State private var newCourseName = ""
    @State private var creatingTopic = false
    @State private var newTopicName = ""
    @State private var openTopic: Topic?

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Formación", back: { dismiss() }) {
                Menu {
                    Button("Nuevo curso") { creatingCourse = true }
                    Button("Nuevo tema") { creatingTopic = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Añadir")
            }

            ScrollView {
                VStack(spacing: 20) {
                    coursesBlock
                    topicsBlock
                    noteNote
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Nuevo curso", isPresented: $creatingCourse) {
            TextField("Nombre", text: $newCourseName)
            Button("Cancelar", role: .cancel) { newCourseName = "" }
            Button("Crear") { createCourse() }
        } message: {
            Text("Luego le pones cuántas lecciones tiene.")
        }
        .alert("Nuevo tema", isPresented: $creatingTopic) {
            TextField("SwiftUI, nutrición, finanzas…", text: $newTopicName)
            Button("Cancelar", role: .cancel) { newTopicName = "" }
            Button("Crear") { createTopic() }
        }
        .sheet(item: $openTopic) { topic in
            TopicNotesView(topic: topic)
        }
    }

    // MARK: - Cursos

    private var coursesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Cursos", trailing: courses.isEmpty ? nil : "\(courses.count)")

            if courses.isEmpty {
                Text("Nada en marcha ahora mismo.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(courses) { course in
                        courseCard(course)
                    }
                }
            }
        }
    }

    private func courseCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(course.name)
                    .font(TCFont.font(15, .medium))
                    .foregroundStyle(course.isFinished ? TCColor.textSoft : TCColor.text)
                Spacer(minLength: 8)
                Text("\((course.progress * 100).formatted(.number.precision(.fractionLength(0)))) %")
                    .font(TCFont.font(13, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(course.isFinished ? TCColor.textMicro : TCColor.moss)
            }

            TCProgressBar(value: course.progress,
                          tint: course.isFinished ? TCColor.textFaint : TCColor.moss)

            HStack {
                Text(course.isFinished
                     ? "terminado · se queda como registro"
                     : "lección \(course.currentLesson) de \(course.totalLessons)")
                    .tcMicro()
                Spacer(minLength: 8)
                if !course.isFinished {
                    Button("+1 lección") { advance(course) }
                        .font(TCFont.font(11, .medium))
                        .foregroundStyle(TCColor.moss)
                }
            }
        }
        .tcCard(padding: 15)
        .contextMenu {
            Button("Quitar una lección") { course.currentLesson = max(0, course.currentLesson - 1); try? context.save() }
            Button("Cambiar total a \(course.totalLessons + 10)") { course.totalLessons += 10; try? context.save() }
            Button("Borrar", role: .destructive) { context.delete(course); try? context.save() }
        }
    }

    private func advance(_ course: Course) {
        course.currentLesson = min(course.totalLessons, course.currentLesson + 1)
        course.lastTouched = .now
        if course.currentLesson >= course.totalLessons, course.finishedAt == nil {
            course.finishedAt = .now
        }
        try? context.save()
    }

    // MARK: - Conocimientos

    private var topicsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Conocimientos")

            if topics.isEmpty {
                Text("Un tema es una carpeta de notas: SwiftUI, nutrición, lo que sea.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                          spacing: 10) {
                    ForEach(topics) { topic in
                        Button { openTopic = topic } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundStyle(TCColor.moss)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(topic.name)
                                        .font(TCFont.font(14, .medium))
                                        .foregroundStyle(TCColor.text)
                                        .lineLimit(1)
                                    Text("\(topic.notes.count) notas").tcMicro()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tcCard(padding: 14, radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var noteNote: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("QUÉ ES UNA NOTA").tcLabel()
            Text("Título, cuerpo y de dónde salió. Eso último permite que un subrayado de Biblioteca llegue aquí con su origen puesto.")
                .font(TCFont.font(12.5))
                .foregroundStyle(TCColor.textSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard(padding: 16, sunken: true)
    }

    // MARK: - Acciones

    private func createCourse() {
        let name = newCourseName.trimmingCharacters(in: .whitespacesAndNewlines)
        newCourseName = ""
        guard !name.isEmpty else { return }
        context.insert(Course(name: name, totalLessons: 10))
        try? context.save()
    }

    private func createTopic() {
        let name = newTopicName.trimmingCharacters(in: .whitespacesAndNewlines)
        newTopicName = ""
        guard !name.isEmpty else { return }
        context.insert(Topic(name: name, order: topics.count))
        try? context.save()
    }
}

// MARK: - Notas de un tema

private struct TopicNotesView: View {
    @Bindable var topic: Topic

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var body_ = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cerrar") { dismiss() }
                    .font(TCFont.font(14)).foregroundStyle(TCColor.textSoft)
                Spacer()
                Text(topic.name).font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
                Spacer()
                Button("Añadir") { add() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(canAdd ? TCColor.moss : TCColor.textFaint)
                    .disabled(!canAdd)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 16)
            .background(TCColor.cardSunken)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        TCSectionLabel(text: "Nota nueva")
                        TextField("Título", text: $title)
                            .font(TCFont.font(14, .medium))
                            .foregroundStyle(TCColor.text)
                        Divider().overlay(TCColor.line)
                        TextField("Lo que no quieres olvidar", text: $body_, axis: .vertical)
                            .font(TCFont.font(13))
                            .foregroundStyle(TCColor.textSoft)
                            .lineLimit(3...8)
                    }
                    .tcCard(padding: 14)

                    if !topic.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            TCSectionLabel(text: "Guardadas", trailing: "\(topic.notes.count)")
                            VStack(spacing: 0) {
                                ForEach(Array(sortedNotes.enumerated()), id: \.element.persistentModelID) { index, note in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(note.title)
                                            .font(TCFont.font(13.5, .medium))
                                            .foregroundStyle(TCColor.text)
                                        if !note.body.isEmpty {
                                            Text(note.body).tcMicro()
                                        }
                                        if !note.source.isEmpty {
                                            Text(note.source)
                                                .font(TCFont.font(10))
                                                .foregroundStyle(TCColor.moss)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 11)
                                    .contextMenu {
                                        Button("Borrar", role: .destructive) {
                                            context.delete(note)
                                            try? context.save()
                                        }
                                    }

                                    if index < sortedNotes.count - 1 { Divider().overlay(TCColor.line) }
                                }
                            }
                            .tcCard(padding: 14)
                        }
                    }
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
    }

    private var sortedNotes: [StudyNote] {
        topic.notes.sorted { $0.createdAt > $1.createdAt }
    }

    private var canAdd: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    private func add() {
        let note = StudyNote(title: title.trimmingCharacters(in: .whitespaces), body: body_)
        context.insert(note)
        note.topic = topic
        try? context.save()
        title = ""
        body_ = ""
    }
}
