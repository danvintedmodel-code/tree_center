import SwiftData
import SwiftUI
import TreeCenterData

// Formación: la lista de cursos. Cada curso abre el mismo espacio de trabajo
// que un proyecto, más la tarjeta de lecciones, cuya fecha también cuenta en
// las estadísticas.

struct LearningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Course.name) private var courses: [Course]

    @State private var adding = false
    @State private var newName = ""
    @State private var newLessons = "10"

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Formación",
                           subtitle: courses.isEmpty ? nil : "\(courses.count) cursos",
                           back: { dismiss() }) {
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Nuevo curso")
            }

            ScrollView {
                VStack(spacing: 14) {
                    if courses.isEmpty {
                        VStack(spacing: 8) {
                            Text("Ningún curso todavía").tcRow()
                            Text("Cada curso lleva sus lecciones, tareas, notas, ideas y avisos.")
                                .tcMicro()
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .tcCard(padding: 16, sunken: true)
                    }

                    ForEach(courses) { course in
                        NavigationLink {
                            WorkspaceView(owner: course, subtitle: lessonsLine(course), course: course)
                        } label: {
                            WorkspaceCard(owner: course, status: lessonsLine(course), progress: course.progress)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Borrar", role: .destructive) { delete(course) }
                        }
                    }
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Nuevo curso", isPresented: $adding) {
            TextField("Nombre", text: $newName)
            TextField("Lecciones", text: $newLessons)
                .keyboardType(.numberPad)
            Button("Cancelar", role: .cancel) { newName = "" }
            Button("Crear") { create() }
        }
    }

    private func lessonsLine(_ course: Course) -> String {
        course.isFinished ? "terminado" : "\(course.currentLesson) de \(course.totalLessons) lecciones"
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lessons = max(1, Int(newLessons) ?? 10)
        newName = ""
        newLessons = "10"
        guard !name.isEmpty else { return }
        context.insert(Course(name: name, totalLessons: lessons))
        try? context.save()
    }

    private func delete(_ course: Course) {
        course.reminders.forEach { ReminderScheduler.cancel(id: $0.identifier) }
        context.delete(course)
        try? context.save()
    }
}
