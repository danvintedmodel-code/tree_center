import SwiftData
import SwiftUI
import TreeCenterData

// Los avisos de un proyecto o un curso: cada día a una hora, o un día concreto
// a una hora. Se guardan en SwiftData y se programan en el propio iPhone.

struct RemindersView<Owner: WorkspaceOwner>: View {
    let owner: Owner

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var kind: ReminderKind = .daily
    @State private var label = ""
    @State private var time = Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: .now) ?? .now
    @State private var day = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var permission: Bool?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Avisos").font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
                Spacer()
                Button("Listo") { dismiss() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(TCColor.moss)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 16)
            .background(TCColor.cardSunken)

            ScrollView {
                VStack(spacing: 18) {
                    if permission == false {
                        Text("El iPhone no tiene permiso para enseñar avisos de Tree Center. Se activa en Ajustes del iPhone → Notificaciones → Tree Center.")
                            .font(TCFont.font(12))
                            .foregroundStyle(TCColor.clay)
                            .fixedSize(horizontal: false, vertical: true)
                            .tcCard(padding: 14, sunken: true)
                    }

                    form
                    existing

                    Text("Son avisos del propio iPhone: llegan aunque la app esté cerrada, y no necesitan internet ni cuenta.")
                        .tcMicro()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .task {
            if label.isEmpty { label = "Repasar \(owner.name)" }
            permission = await ReminderScheduler.ensurePermission()
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Nuevo")

            HStack(spacing: 7) {
                ForEach(ReminderKind.allCases) { option in
                    Button { kind = option } label: {
                        TCChip(text: option.label, selected: kind == option)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Qué te recuerdo", text: $label)
                .font(TCFont.font(15))
                .foregroundStyle(TCColor.text)
                .tcCard(padding: 14, radius: TCRadius.control)

            HStack(spacing: 10) {
                if kind == .once {
                    DatePicker("", selection: $day, in: Date.now..., displayedComponents: .date)
                        .labelsHidden()
                }
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Spacer()
            }
            .tint(TCColor.moss)

            Button("Guardar aviso", action: save)
                .buttonStyle(TCPrimaryButtonStyle())
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var existing: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Los que tienes")

            if owner.reminders.isEmpty {
                Text("Ninguno todavía.").tcMicro()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(owner.reminders.enumerated()), id: \.element.persistentModelID) { index, reminder in
                        HStack(spacing: 11) {
                            Image(systemName: "bell")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(TCColor.moss)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.label).font(TCFont.font(13.5)).foregroundStyle(TCColor.text)
                                Text(ReminderScheduler.describe(kind: reminder.kind, hour: reminder.hour,
                                                                minute: reminder.minute, date: reminder.date))
                                    .tcMicro()
                            }
                            Spacer(minLength: 8)
                            Button { remove(reminder) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(TCColor.textFaint)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Quitar el aviso")
                        }
                        .padding(.vertical, 12)

                        if index < owner.reminders.count - 1 { Divider().overlay(TCColor.line) }
                    }
                }
                .tcCard(padding: 14)
            }
        }
    }

    private func save() {
        let text = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = WorkReminder(kind: kind, hour: parts.hour ?? 21, minute: parts.minute ?? 30,
                                    date: kind == .once ? day : nil, label: text)
        context.insert(reminder)
        owner.adopt(reminder)
        try? context.save()

        ReminderScheduler.schedule(id: reminder.identifier, title: owner.name, body: text,
                                   kind: reminder.kind, hour: reminder.hour, minute: reminder.minute,
                                   date: reminder.date)
    }

    private func remove(_ reminder: WorkReminder) {
        ReminderScheduler.cancel(id: reminder.identifier)
        context.delete(reminder)
        try? context.save()
    }
}
