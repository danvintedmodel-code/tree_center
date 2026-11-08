import SwiftUI
import TreeCenterData

// Ajustes. Corto a propósito: lo que importa aquí es la entrada y los datos.
//
// Lo que todavía no existe aparece apagado y dicho, no escondido. Un interruptor
// que no hace nada es peor que una línea que admite que falta.

struct SettingsView: View {
    let lock: LockController

    @Environment(\.dismiss) private var dismiss
    @AppStorage(LockController.biometricsPreferenceKey) private var useFaceID = true

    @State private var confirmingReset = false

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
            TCSectionLabel(text: "Datos")

            VStack(spacing: 0) {
                pendingRow("Copia en iCloud", note: "pendiente")
                Divider().overlay(TCColor.line)
                pendingRow("Exportar todo", note: "pendiente")
                Divider().overlay(TCColor.line)
                HStack {
                    Text("Apariencia").font(TCFont.font(14)).foregroundStyle(TCColor.text)
                    Spacer()
                    Text("Sigue al sistema").tcMicro()
                }
                .padding(.vertical, 13)
            }
            .tcCard(padding: 16)
        }
    }

    private func pendingRow(_ title: String, note: String) -> some View {
        HStack {
            Text(title).font(TCFont.font(14)).foregroundStyle(TCColor.textFaint)
            Spacer()
            Text(note)
                .font(TCFont.font(10, .semibold))
                .tracking(0.6)
                .foregroundStyle(TCColor.textMicro)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(Capsule().stroke(TCColor.line, lineWidth: 1))
        }
        .padding(.vertical, 13)
    }

    // MARK: - Pie

    private var footer: some View {
        VStack(spacing: 6) {
            TreeMark(size: 28, tint: TCColor.textFaint)
            Text("Tree Center 0.1")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textMicro)
            Text("El trazo y Face ID no salen de este iPhone.")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }
}
