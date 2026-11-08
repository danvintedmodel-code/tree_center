import SwiftData
import SwiftUI
import TreeCenterData

// Emprendimientos. Un proyecto, su estado y un único siguiente paso visible.
// Lo demás cabe dentro; esto es la portada.

struct ProjectsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Project.startedAt, order: .reverse) private var projects: [Project]

    @State private var filter: ProjectStatus? = .running
    @State private var creating = false
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Emprendimientos", back: { dismiss() }) {
                Button { creating = true } label: {
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
                    statusChips

                    if shown.isEmpty {
                        emptyState
                    } else {
                        ForEach(shown) { project in
                            card(project)
                        }
                    }

                    diaryNote
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Nuevo proyecto", isPresented: $creating) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) { newName = "" }
            Button("Crear") { create() }
        }
    }

    private var shown: [Project] {
        guard let filter else { return projects }
        return projects.filter { $0.status == filter }
    }

    private var statusChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(ProjectStatus.allCases) { status in
                    Button { filter = filter == status ? nil : status } label: {
                        TCChip(text: status.label, selected: filter == status)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(filter == nil ? "Sin proyectos" : "Nada \(filter!.label.lowercased())")
                .tcRow()
            Text("Una idea apuntada ya es más que una idea en la cabeza.")
                .tcMicro()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .tcCard(padding: 16, sunken: true)
    }

    // MARK: - Tarjeta

    private func card(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(project.name).tcSection()
                Spacer(minLength: 8)
                Menu {
                    ForEach(ProjectStatus.allCases) { status in
                        Button(status.label) { set(project, to: status) }
                    }
                } label: {
                    Text(project.status.label.uppercased())
                        .font(TCFont.font(10, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(project.status == .running ? TCColor.onMoss : TCColor.textSoft)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(project.status == .running ? TCColor.moss : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(project.status == .running ? Color.clear : TCColor.lineStrong,
                                             lineWidth: 1)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                TCProgressBar(value: project.progress,
                              tint: project.status == .running ? TCColor.moss : TCColor.textFaint)
                HStack {
                    Text("\((project.progress * 100).formatted(.number.precision(.fractionLength(0)))) %")
                        .tcMicro()
                        .monospacedDigit()
                    Spacer()
                    Stepper("", value: Binding(
                        get: { project.progress },
                        set: { project.progress = min(1, max(0, $0)); try? context.save() }
                    ), in: 0...1, step: 0.05)
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .frame(width: 86, alignment: .trailing)
                }
            }

            nextStep(project)

            HStack(spacing: 18) {
                figure("Tareas", "\(project.openTasks)")
                figure("Decisiones", "\(project.decisions.count)")
                figure("Desde", project.startedAt.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
            }
        }
        .tcCard(padding: 16)
        .contextMenu {
            Button("Borrar", role: .destructive) {
                context.delete(project)
                try? context.save()
            }
        }
    }

    private func nextStep(_ project: Project) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(project.status == .running ? TCColor.moss : TCColor.textMicro)
                .padding(.top, 2)

            TextField("Siguiente paso", text: Binding(
                get: { project.nextStep },
                set: { project.nextStep = $0 }
            ), axis: .vertical)
            .font(TCFont.font(12.5))
            .foregroundStyle(TCColor.text)
            .onSubmit { try? context.save() }
        }
        .padding(12)
        .background(TCColor.well)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(TCFont.font(10)).foregroundStyle(TCColor.textMicro)
            Text(value)
                .font(TCFont.font(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.text)
        }
    }

    private var diaryNote: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("DIARIO DE DECISIONES").tcLabel()
            Text("Cada proyecto guarda por qué se decidió lo que se decidió, con fecha. Es lo que te salva dentro de seis meses.")
                .font(TCFont.font(12.5))
                .foregroundStyle(TCColor.textSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard(padding: 16, sunken: true)
    }

    // MARK: - Acciones

    private func set(_ project: Project, to status: ProjectStatus) {
        project.statusRaw = status.rawValue
        try? context.save()
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = ""
        guard !name.isEmpty else { return }
        context.insert(Project(name: name, status: .idea))
        try? context.save()
        filter = nil
    }
}
