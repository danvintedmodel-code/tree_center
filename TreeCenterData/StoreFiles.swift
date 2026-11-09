import Foundation

// Dónde vive el almacén, en archivos.
//
// SwiftData, si no le dices nada, lo pone en `Application Support/default.store`.
// Aquí se le dice: `TreeCenter.store`, en el mismo sitio pero con nombre propio.
// No es presumir, es que una copia de seguridad y una restauración necesitan
// saber exactamente qué archivos tocar, y «el sitio por defecto» es una promesa
// que SwiftData no ha hecho por escrito.
//
// El almacén no es un archivo, son cuatro:
//
//   TreeCenter.store        la base
//   TreeCenter.store-wal    lo escrito y todavía no volcado
//   TreeCenter.store-shm    el índice de lo anterior
//   .TreeCenter_SUPPORT/    las fotos, que con `.externalStorage` viven fuera
//
// Copiar solo el primero es la forma más fácil de hacer una copia que parece
// buena y ha perdido lo último que hiciste y todas las fotos.

/// Las preferencias que hacen falta **antes** de que haya una vista: el
/// contenedor se monta en el arranque y tiene que saber ya si va a iCloud.
public enum TreeCenterSettings {
    public static let cloudKey = "tc.useICloud"

    public static var usesCloud: Bool {
        UserDefaults.standard.bool(forKey: cloudKey)
    }
}

public enum StoreFiles {

    public static let storeName = "TreeCenter.store"

    public static var directory: URL {
        URL.applicationSupportDirectory
    }

    public static var storeURL: URL {
        directory.appending(path: storeName)
    }

    /// La carpeta de las fotos. El punto de delante es de SwiftData, no mío.
    public static var supportURL: URL {
        directory.appending(path: ".TreeCenter_SUPPORT")
    }

    /// Donde se deja una copia importada hasta el siguiente arranque. Ver
    /// `applyPendingRestore()`.
    public static var pendingRestoreURL: URL {
        directory.appending(path: "restauracion-pendiente")
    }

    /// Application Support no siempre existe en una instalación nueva.
    public static func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
    }

    // MARK: - Qué hay ahora mismo

    /// Los trozos del almacén que existen de verdad, listos para copiar.
    public static func pieces() -> [URL] {
        let candidates = [
            storeURL,
            directory.appending(path: storeName + "-wal"),
            directory.appending(path: storeName + "-shm"),
            supportURL
        ]
        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Lo que ocupa todo junto. Recorre la carpeta de fotos entera, así que no
    /// conviene llamarlo en cada repintado de una vista.
    public static func totalBytes() -> Int64 {
        pieces().reduce(0) { $0 + bytes(at: $1) }
    }

    public static func photoBytes() -> Int64 {
        bytes(at: supportURL)
    }

    private static func bytes(at url: URL) -> Int64 {
        let manager = FileManager.default

        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            let attributes = try? manager.attributesOfItem(atPath: url.path)
            // `.size` llega como NSNumber, no como Int64: el puente directo
            // falla y el peso sale a cero sin decir nada.
            return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        }

        guard let walker = manager.enumerator(at: url,
                                              includingPropertiesForKeys: [.fileSizeKey],
                                              options: []) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in walker {
            let values = try? child.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    // MARK: - Restaurar

    /// Mete en su sitio una copia importada, si hay una esperando.
    ///
    /// Esto **tiene que correr antes de abrir el `ModelContainer`**. Sustituir
    /// los archivos de un almacén que está abierto no da un error: da una base
    /// de datos a medias, que es mucho peor. Por eso una restauración no se
    /// aplica cuando la pides, se deja aquí y se aplica en el siguiente
    /// arranque, con la app recién abierta y el almacén todavía cerrado.
    ///
    /// Devuelve true si ha restaurado algo.
    @discardableResult
    public static func applyPendingRestore() -> Bool {
        let manager = FileManager.default
        let incoming = pendingRestoreURL

        guard manager.fileExists(atPath: incoming.path),
              manager.fileExists(atPath: incoming.appending(path: storeName).path) else {
            // Una carpeta a medias (importación interrumpida) se tira: dejarla
            // ahí haría que el próximo arranque lo intentara otra vez.
            try? manager.removeItem(at: incoming)
            return false
        }

        // Fuera lo que hay. Si esto falla a medias, el siguiente paso lo pisa
        // igual, porque los nombres son los mismos.
        for piece in pieces() {
            try? manager.removeItem(at: piece)
        }

        var restored = false
        if let children = try? manager.contentsOfDirectory(at: incoming,
                                                           includingPropertiesForKeys: nil) {
            for child in children {
                let destination = directory.appending(path: child.lastPathComponent)
                try? manager.removeItem(at: destination)
                do {
                    try manager.moveItem(at: child, to: destination)
                    if child.lastPathComponent == storeName { restored = true }
                } catch {
                    continue
                }
            }
        }

        try? manager.removeItem(at: incoming)
        return restored
    }
}
