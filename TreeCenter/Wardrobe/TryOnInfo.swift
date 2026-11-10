import SwiftUI

// La prueba con IA: una foto tuya y la de la prenda, y un servicio devuelve una
// imagen tuya llevándola. Es lo más cerca de «casi real» que se puede llegar.
//
// Está apagada a propósito. Es lo único de la app que rompería la regla de que
// nada sale del iPhone: tu foto viajaría a ese servicio, y cada prueba cuesta
// dinero. Aquí solo se explica; encenderla es una decisión aparte.

struct TryOnInfo: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        box("Tú", "una foto tuya")
                        Text("+").tcMicro()
                        box("Prenda", "la de tu armario")
                        Text("=").tcMicro()
                        box("Resultado", "tú con ella puesta")
                    }
                    Text("Un servicio de IA coge una foto tuya y la de la prenda, y devuelve una imagen tuya llevándola: con caída, arrugas y luz.")
                        .font(TCFont.font(13))
                        .foregroundStyle(TCColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tcCard(padding: 16)

                VStack(alignment: .leading, spacing: 10) {
                    TCSectionLabel(text: "Lo que cuesta")
                    VStack(spacing: 0) {
                        row("Por imagen", "entre 4 y 15 céntimos")
                        Divider().overlay(TCColor.line)
                        row("Necesita", "internet, cada vez")
                        Divider().overlay(TCColor.line)
                        row("Tu foto", "sale del iPhone hacia el servicio")
                        Divider().overlay(TCColor.line)
                        row("Tarda", "unos segundos por prueba")
                    }
                    .tcCard(padding: 14)
                }

                Text("Por eso va aparte y apagado. El maniquí plano funciona sin nada de esto.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Probármelo · sin activar") {}
                    .buttonStyle(TCPrimaryButtonStyle())
                    .disabled(true)
                    .opacity(0.45)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func box(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(TCFont.font(12, .medium)).foregroundStyle(TCColor.text)
            Text(subtitle)
                .font(TCFont.font(9.5))
                .foregroundStyle(TCColor.textMicro)
                .multilineTextAlignment(.center)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.75, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(TCColor.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).tcMicro()
            Spacer(minLength: 8)
            Text(value)
                .font(TCFont.font(13))
                .foregroundStyle(TCColor.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
    }
}
