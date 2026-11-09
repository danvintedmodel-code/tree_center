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
    @AppStorage(TreeCenterSettings.cloudKey) private var useICloud = false

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
                    entranceBlock
                    dataBlock
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
                HStack(spacing: 11) {
                    Image(systemName: "icloud")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(TCColor.textSoft)
                        .frame(width: 22)
                    Text("Copia en iCloud").font(TCFont.font(14)).foregroundStyle(TCColor.text)
                    Spacer(minLength: 8)
                    Toggle("", isOn: $useICloud)
                        .labelsHidden()
                        .tint(TCColor.moss)
                }
                .padding(.vertical, 13)

                Divider().overlay(TCColor.line)

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
        La copia lleva la base y las fotos. iCloud se enciende al reiniciar la \
        app y necesita el permiso puesto en Xcode; si no está, la app sigue \
        guardando en el iPhone y no se pierde nada.
        """
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
            // El trazo sigue sin salir incluso con iCloud encendido: vive en el
            // Keychain marcado como «solo este dispositivo» y no entra ni en la
            // copia ni en el respaldo del iPhone.
            Text(useICloud
                 ? "El trazo y Face ID no salen de este iPhone. El resto, sí: va a tu iCloud."
                 : "Nada de esto sale de este iPhone.")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}
