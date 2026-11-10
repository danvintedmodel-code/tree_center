import SwiftData
import SwiftUI
import TreeCenterData
import UniformTypeIdentifiers

// Ajustes. Corto a propósito: lo que importa aquí es la entrada y los datos.
//
// Lo que todavía no existe aparece apagado y dicho, no escondido. Un interruptor
// que no hace nada es peor que una línea que admite que falta.

struct SettingsView: View {
    let lock: LockController

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var movements: [Movement]

    @AppStorage(LockController.biometricsPreferenceKey) private var useFaceID = true
    @AppStorage(InstallInfo.expiryWarnKey) private var expiryWarn = true
    @AppStorage(InstallInfo.backupWarnKey) private var backupWarn = true

    @State private var repairing = false
    @State private var repairReport: String?

    @State private var confirmingReset = false
    @State private var shared: SharedFile?
    @State private var importing = false
    @State private var restoreReady = false
    @State private var problem: String?
    @State private var weightLine = "…"

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Ajustes", back: { dismiss() })

            ScrollView {
                VStack(spacing: 20) {
                    installBlock
                    entranceBlock
                    dataBlock
                    appBlock
                    footer
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .alert("¿Cambiar el trazo?", isPresented: $confirmingReset) {
            Button("Cancelar", role: .cancel) {}
            Button("Cambiarlo", role: .destructive) {
                lock.resetPattern()
                dismiss()
            }
        } message: {
            Text("Se borra el actual y la app te pide dibujar uno nuevo dos veces.")
        }
        .sheet(item: $shared) { file in
            ShareSheet(url: file.url)
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.data],
                      onCompletion: receive)
        .alert("Copia lista para entrar", isPresented: $restoreReady) {
            Button("Entendido") {}
        } message: {
            Text("Cierra Tree Center del todo y vuelve a abrirla. La copia entra en ese arranque, con la base cerrada: hacerlo ahora, con la app funcionando, es la forma de romperla.")
        }
        .alert("No ha salido", isPresented: .init(get: { problem != nil },
                                                 set: { if !$0 { problem = nil } })) {
            Button("Vale") { problem = nil }
        } message: {
            Text(problem ?? "")
        }
        .task { refreshWeight() }
    }

    // MARK: - Entrada

    private var entranceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Entrada")

            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    Image(systemName: "faceid")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(TCColor.textSoft)
                        .frame(width: 22)
                    Text(biometricsLabel).font(TCFont.font(14)).foregroundStyle(TCColor.text)
                    Spacer(minLength: 8)
                    Toggle("", isOn: $useFaceID)
                        .labelsHidden()
                        .tint(TCColor.moss)
                        .disabled(BiometricAuth.available == .none)
                }
                .padding(.vertical, 13)

                Divider().overlay(TCColor.line)

                Button { confirmingReset = true } label: {
                    HStack {
                        Text("Cambiar el trazo").font(TCFont.font(14)).foregroundStyle(TCColor.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TCColor.textFaint)
                    }
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(TCColor.line)

                HStack {
                    Text("Bloquear al salir").font(TCFont.font(14)).foregroundStyle(TCColor.text)
                    Spacer()
                    Text("Al instante").tcMicro()
                }
                .padding(.vertical, 13)
            }
            .tcCard(padding: 16)

            Text(biometricsFootnote)
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textMicro)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var biometricsLabel: String {
        switch BiometricAuth.available {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "Biometría no disponible"
        }
    }

    private var biometricsFootnote: String {
        BiometricAuth.available == .none
            ? "Este dispositivo no tiene biometría: se entra siempre con el trazo."
            : "La puerta rápida. Si la apagas o falla, el trazo entra igual."
    }

    // MARK: - Datos

    private var dataBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Datos", trailing: weightLine)

            VStack(spacing: 0) {
                actionRow("Guardar una copia",
                          note: "un archivo con todo",
                          symbol: "arrow.down.doc") { makeBackup() }

                Divider().overlay(TCColor.line)

                actionRow("Exportar los gastos",
                          note: movements.isEmpty ? "nada que exportar" : "\(movements.count) movimientos en CSV",
                          symbol: "tablecells",
                          enabled: !movements.isEmpty) { exportMovements() }

                Divider().overlay(TCColor.line)

                actionRow("Restaurar una copia",
                          note: "se aplica al reiniciar",
                          symbol: "arrow.up.doc") { importing = true }

                Divider().overlay(TCColor.line)

                HStack(spacing: 11) {
                    Text("Recordarme la copia cada domingo")
                        .font(TCFont.font(14))
                        .foregroundStyle(TCColor.text)
                    Spacer(minLength: 8)
                    Toggle("", isOn: $backupWarn)
                        .labelsHidden()
                        .tint(TCColor.moss)
                        .onChange(of: backupWarn) { _, on in
                            Task {
                                if on { _ = await ReminderScheduler.ensurePermission() }
                                InstallInfo.scheduleBackupReminder(enabled: on)
                            }
                        }
                }
                .padding(.vertical, 13)

                Divider().overlay(TCColor.line)

                HStack {
                    Text("Apariencia").font(TCFont.font(14)).foregroundStyle(TCColor.text)
                    Spacer()
                    Text("Sigue al sistema").tcMicro()
                }
                .padding(.vertical, 13)
            }
            .tcCard(padding: 16)

            Text(dataFootnote)
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textMicro)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataFootnote: String {
        """
        La copia lleva la base y las fotos. Instalada gratis no hay iCloud \
        automático, así que la copia es lo que te salva si pierdes el móvil: \
        guárdala en Archivos → iCloud Drive.
        """
    }

    // MARK: - Esta instalación

    /// La cuenta atrás de los 7 días de la firma gratuita, con su aviso.
    private var installBlock: some View {
        let left = InstallInfo.daysLeft()

        return VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Esta instalación")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(InstallInfo.describe())
                        .font(TCFont.font(15, .semibold))
                        .foregroundStyle((left ?? 7) <= 1 ? TCColor.clay : TCColor.text)
                    Spacer()
                    if let expires = InstallInfo.signature?.expires {
                        Text(expires.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                            .tcMicro()
                    }
                }

                if let left {
                    TCProgressBar(value: Double(max(0, min(7, left))) / 7,
                                  tint: left <= 1 ? TCColor.clay : TCColor.moss)
                }

                HStack(spacing: 11) {
                    Text("Avisarme el día antes").font(TCFont.font(14)).foregroundStyle(TCColor.text)
                    Spacer(minLength: 8)
                    Toggle("", isOn: $expiryWarn)
                        .labelsHidden()
                        .tint(TCColor.moss)
                        .onChange(of: expiryWarn) { _, on in
                            Task {
                                if on { _ = await ReminderScheduler.ensurePermission() }
                                InstallInfo.scheduleExpiryWarning(enabled: on)
                            }
                        }
                }
            }
            .tcCard(padding: 16)

            Text(left == nil
                 ? "Esta instalación no trae fecha de caducidad: viene de Xcode o del simulador."
                 : "Pasados los 7 días la app no abre, pero tus datos se quedan. Para renovarla: Sideloadly en el PC con el iPhone conectado.")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textMicro)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Aplicación

    private var appBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Aplicación")

            VStack(spacing: 0) {
                HStack {
                    Text("Versión").font(TCFont.font(14)).foregroundStyle(TCColor.text)
                    Spacer()
                    Text(version).tcMicro()
                }
                .padding(.vertical, 13)

                Divider().overlay(TCColor.line)

                actionRow("Reparar la app",
                          note: repairReport ?? "si algo se ha quedado raro",
                          symbol: "wrench.and.screwdriver",
                          enabled: !repairing) { Task { await repair() } }
            }
            .tcCard(padding: 16)

            Text("iOS no deja que una app se actualice sola. Cada versión nueva se instala igual que se renueva: desde el PC, encima de la que tienes, y tus datos siguen dentro.")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textMicro)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// Lo que de verdad arregla, sin tocar ningún dato tuyo: vacía los archivos
    /// temporales (copias y CSV ya compartidos), vuelve a programar todos los
    /// avisos por si alguno se perdió al reinstalar, y corrige repartos de
    /// carteras que pasen de 100 %.
    @MainActor
    private func repair() async {
        repairing = true
        defer { repairing = false }

        // 1. Archivos temporales.
        let temp = FileManager.default.temporaryDirectory
        let leftovers = (try? FileManager.default.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil)) ?? []
        leftovers.forEach { try? FileManager.default.removeItem(at: $0) }

        // 2. Avisos.
        let permitted = await ReminderScheduler.ensurePermission()
        let reminders = (try? context.fetch(FetchDescriptor<WorkReminder>())) ?? []
        if permitted {
            for reminder in reminders {
                let title = reminder.project?.name ?? reminder.course?.name ?? "Tree Center"
                ReminderScheduler.schedule(id: reminder.identifier, title: title, body: reminder.label,
                                           kind: reminder.kind, hour: reminder.hour, minute: reminder.minute,
                                           date: reminder.date)
            }
            InstallInfo.scheduleExpiryWarning(enabled: expiryWarn)
            InstallInfo.scheduleBackupReminder(enabled: backupWarn)
        }

        // 3. Repartos que se pasan.
        let wallets = (try? context.fetch(FetchDescriptor<Wallet>(sortBy: [SortDescriptor(\.order)]))) ?? []
        var fixed = 0
        var running = 0
        for wallet in wallets {
            let allowed = max(0, 100 - running)
            if wallet.allocationPercent > allowed {
                wallet.allocationPercent = allowed
                fixed += 1
            }
            running += wallet.allocationPercent
        }
        try? context.save()

        refreshWeight()
        repairReport = "Hecho: \(leftovers.count) temporales fuera, \(reminders.count) avisos al día"
            + (fixed > 0 ? ", \(fixed) repartos corregidos" : "")
            + (permitted ? "" : " (sin permiso de avisos)")
    }

    private func actionRow(_ title: String, note: String, symbol: String,
                           enabled: Bool = true, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(enabled ? TCColor.textSoft : TCColor.textFaint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TCFont.font(14))
                        .foregroundStyle(enabled ? TCColor.text : TCColor.textFaint)
                    Text(note)
                        .font(TCFont.font(10.5))
                        .foregroundStyle(TCColor.textMicro)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TCColor.textFaint)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Lo que hacen esos botones

    /// Guardar antes de copiar: lo que esté sin volcar no está en los archivos,
    /// y una copia a la que le falta lo último que hiciste es una trampa.
    private func makeBackup() {
        try? context.save()
        do {
            shared = SharedFile(url: try StoreArchive.write())
        } catch {
            problem = error.localizedDescription
        }
    }

    private func exportMovements() {
        do {
            let csv = StoreArchive.movementsCSV(movements)
            shared = SharedFile(url: try StoreArchive.writeCSV(csv, named: "TreeCenter-gastos.csv"))
        } catch {
            problem = "No se ha podido escribir el CSV."
        }
    }

    /// El archivo elegido vive fuera de la app y hay que pedir permiso para
    /// leerlo, y devolverlo al terminar.
    private func receive(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            problem = "No se ha podido abrir ese archivo."

        case .success(let url):
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }

            do {
                try StoreArchive.stageForRestore(from: url)
                restoreReady = true
            } catch {
                problem = error.localizedDescription
            }
        }
    }

    private func refreshWeight() {
        let bytes = StoreFiles.totalBytes()
        let photos = StoreFiles.photoBytes()
        guard bytes > 0 else { weightLine = "vacío"; return }

        weightLine = photos > 0
            ? "\(StoreArchive.weight(bytes)) · \(StoreArchive.weight(photos)) en fotos"
            : StoreArchive.weight(bytes)
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: 6) {
            TreeMark(size: 28, tint: TCColor.textFaint)
            Text("Tree Center 0.1")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textMicro)
            Text("Nada de esto sale de este iPhone.")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}
