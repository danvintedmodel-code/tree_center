import SwiftData
import SwiftUI
import TreeCenterData

// Emprendimientos: la lista de proyectos. Cada uno abre su espacio de trabajo
// (resumen, tareas, notas, ideas y avisos), el mismo que usan los cursos.

struct ProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.startedAt) private var projects: [Project]

    @State private var adding = false
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Emprendimientos",
                           subtitle: projects.isEmpty ? nil : "\(projects.count) proyectos",
                           back: { dismiss() }) {
                Button { adding = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TCColor.text)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .accessibilityLabel("Nuevo proyecto")
            }

            ScrollView {
                VStack(spacing: 14) {
                    if projects.isEmpty {
                        VStack(spacing: 8) {
                            Text("Ningún proyecto todavía").tcRow()
                            Text("Cada proyecto lleva sus tareas, sus notas del día, sus ideas y sus avisos, con estadísticas de lo que vas haciendo.")
                                .tcMicro()
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .tcCard(padding: 16, sunken: true)
                    }

                    ForEach(projects) { project in
                        NavigationLink {
                            WorkspaceView(owner: project, subtitle: project.status.label)
                        } label: {
                            WorkspaceCard(owner: project, status: project.status.label, progress: project.doneShare)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Menu("Estado") {
                                ForEach(ProjectStatus.allCases) { status in
                                    Button(status.label) {
                                        project.statusRaw = status.rawValue
                                        try? context.save()
                                    }
                                }
                            }
                            Button("Borrar", role: .destructive) { delete(project) }
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
        .alert("Nuevo proyecto", isPresented: $adding) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) { newName = "" }
            Button("Crear") { create() }
        }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = ""
        guard !name.isEmpty else { return }
        context.insert(Project(name: name, status: .running))
        try? context.save()
    }

    /// Antes de borrar, se cancelan sus avisos: si no, seguirían sonando por un
    /// proyecto que ya no existe.
    private func delete(_ project: Project) {
        project.reminders.forEach { ReminderScheduler.cancel(id: $0.identifier) }
        context.delete(project)
        try? context.save()
    }
}
