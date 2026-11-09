import UIKit

// Lo que se guarda no es la foto que da el iPhone.
//
// Una foto de 12 Mpx son unos 4 MB. Con cien recetas, prendas y recibos eso es
// casi medio giga dentro de la app, y la pantalla mide 390 pt de ancho: nadie
// va a ver esos píxeles nunca. Así que todo pasa por aquí antes de entrar:
// lado mayor a 1400 px y compresión.
//
// El PNG con fondo recortado sí importa (las prendas del armario son eso), así
// que si la imagen trae canal alfa se guarda en PNG y no en JPEG, que lo
// aplanaría a un rectángulo blanco.

enum TCImage {
    /// Suficiente para que se vea bien a pantalla completa en un 17 Pro Max y
    /// para recortar un trozo sin que se note.
    static let maxSide: CGFloat = 1400

    static let jpegQuality: CGFloat = 0.82

    static func prepared(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return prepared(image)
    }

    static func prepared(_ image: UIImage) -> Data? {
        let scaled = downscaled(image)
        return hasAlpha(scaled)
            ? scaled.pngData()
            : scaled.jpegData(compressionQuality: jpegQuality)
    }

    /// Lo que ocupa ya guardado, para poder decirlo en Ajustes.
    static func weight(_ data: Data) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }

    // MARK: - Dentro

    private static func downscaled(_ image: UIImage) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide, side > 0 else { return image }

        let ratio = maxSide / side
        let size = CGSize(width: (image.size.width * ratio).rounded(),
                          height: (image.size.height * ratio).rounded())

        // scale = 1 para que el tamaño sea en píxeles de verdad: con el scale
        // del dispositivo saldría una imagen 3 veces más grande de lo pedido.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = !hasAlpha(image)

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            // `draw(in:)` respeta la orientación EXIF, así que una foto hecha
            // en vertical no sale tumbada.
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func hasAlpha(_ image: UIImage) -> Bool {
        guard let info = image.cgImage?.alphaInfo else { return false }
        switch info {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }
}
