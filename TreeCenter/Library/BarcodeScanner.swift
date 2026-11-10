import SwiftUI
import VisionKit

// Leer el código de barras de un libro con la cámara.
//
// `DataScannerViewController` es el lector de Apple (el mismo que lee texto en
// la cámara del iPhone). Pide un chip A12 o posterior, que el iPhone 13 Pro
// tiene de sobra, y no existe en el simulador: por eso `isAvailable` decide si
// se enseña el botón o solo el campo para escribir el ISBN a mano.

struct BarcodeScanner: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    /// En el hilo principal, como todo `DataScannerViewController`: preguntarle
    /// desde otro sitio es un error de compilación, no un aviso.
    @MainActor
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            // EAN-13 es el código de los libros (el ISBN-13 va dentro).
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        // Arranca cuando la vista ya está en pantalla: antes no hay cámara.
        DispatchQueue.main.async { try? scanner.startScanning() }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let parent: BarcodeScanner
        private var done = false

        init(_ parent: BarcodeScanner) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            // Solo el primero: el escáner sigue viendo el código mientras se
            // cierra, y sin esta guarda se buscaría el mismo libro varias veces.
            guard !done else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    done = true
                    dataScanner.stopScanning()
                    parent.onFound(value)
                    parent.dismiss()
                    return
                }
            }
        }
    }
}
