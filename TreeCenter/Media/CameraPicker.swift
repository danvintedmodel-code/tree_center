import SwiftUI
import UIKit

// La cámara. SwiftUI no trae ninguna, así que es `UIImagePickerController`
// envuelto.
//
// Dos cosas que hay que tener presentes:
//
// 1. En el simulador no existe. `isAvailable` es false allí, y por eso el botón
//    de la cámara no se dibuja en vez de dibujarse y no hacer nada.
// 2. Sin `NSCameraUsageDescription` en el Info.plist, iOS mata la app en el
//    momento de abrirla. No es un aviso: es un crash. Está en el README.

struct CameraPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
