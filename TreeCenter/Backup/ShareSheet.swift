import SwiftUI
import UIKit

// La hoja de compartir de iOS, para sacar la copia o el CSV de la app.
//
// `ShareLink` sería más corto, pero quiere el archivo hecho ya cuando se dibuja
// el botón, y aquí el archivo se escribe al pulsar: hacer una copia del almacén
// en cada repintado de Ajustes no tiene ninguna gracia.

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Un archivo listo para compartir. Envuelto en un tipo con id propio porque
/// `.sheet(item:)` pide Identifiable y una URL no lo es.
struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}
