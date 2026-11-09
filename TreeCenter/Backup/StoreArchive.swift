import AppleArchive
import Foundation
import System
import TreeCenterData

// La copia de seguridad: los cuatro trozos del almacén metidos en un archivo.
//
// Por qué `.aar` de Apple Archive y no un `.zip`:
//
// Foundation sabe hacer un zip (`NSFileCoordinator` con `.forUploading`) pero
// **no sabe deshacerlo**. No hay API pública para descomprimir un zip en iOS,
// así que una copia en zip sería una copia que no se puede restaurar sin meter
// una dependencia de terceros. Apple Archive va en los dos sentidos y viene en
// el sistema.
//
// El precio es que no se abre con doble clic en el Mac. Se abre con una orden,
// que está escrita en el README:
//
//     aa extract -i TreeCenter-copia.aar -d carpeta
//
// Y para lo de leerlo con los ojos está la exportación a CSV de aquí abajo, que
// es lo que de verdad se quiere cuando se dice «exportar».

enum StoreArchive {

    enum Failure: LocalizedError {
        case nothingToSave
        case cannotWrite
        case cannotRead
        case notATreeCenterBackup

        var errorDescription: String? {
            switch self {
            case .nothingToSave: return "Todavía no hay nada guardado que copiar."
            case .cannotWrite: return "No se ha podido escribir la copia."
            case .cannotRead: return "Ese archivo no se ha podido leer."
            case .notATreeCenterBackup: return "Ese archivo no es una copia de Tree Center."
            }
        }
    }

    /// Los campos que se guardan de cada archivo. Sin `DAT` no se guarda el
    /// contenido, solo los nombres: una copia vacía que parece una copia.
    private static var keys: ArchiveHeader.FieldKeySet {
        ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")!
    }

    // MARK: - Hacer la copia

    /// Deja la copia en un archivo temporal y devuelve dónde.
    ///
    /// Antes de llamar hay que guardar el contexto: lo que esté sin guardar no
    /// está en los archivos y no entra en la copia.
    static func write() throws -> URL {
        let pieces = StoreFiles.pieces()
        guard !pieces.isEmpty else { throw Failure.nothingToSave }

        // Apple Archive empaqueta una carpeta, así que primero se junta todo en
        // una. Se copia y no se mueve, obviamente: son los archivos vivos.
        let staging = FileManager.default.temporaryDirectory
            .appending(path: "copia-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        for piece in pieces {
            try FileManager.default.copyItem(
                at: piece,
                to: staging.appending(path: piece.lastPathComponent)
            )
        }

        let output = FileManager.default.temporaryDirectory.appending(path: filename())
        try? FileManager.default.removeItem(at: output)

        guard let file = ArchiveByteStream.fileStream(
                path: FilePath(output.path),
                mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)),
              let compression = ArchiveByteStream.compressionStream(using: .lzfse,
                                                                    writingTo: file),
              let encoder = ArchiveStream.encodeStream(writingTo: compression) else {
            throw Failure.cannotWrite
        }

        // A mano y en este orden. Cerrar el de fuera primero deja el archivo
        // sin el final, y un .aar sin final no se puede abrir.
        try encoder.writeDirectoryContents(archiveFrom: FilePath(staging.path), keySet: keys)
        try encoder.close()
        try compression.close()
        try file.close()

        return output
    }

    private static func filename() -> String {
        let stamp = Date().formatted(.iso8601
            .year().month().day()
            .dateSeparator(.dash))
        return "TreeCenter-copia-\(stamp).aar"
    }

    // MARK: - Dejarla lista para restaurar

    /// Saca una copia a la carpeta de restauración pendiente. No toca el
    /// almacén vivo: eso lo hace `StoreFiles.applyPendingRestore()` en el
    /// siguiente arranque, con la base cerrada.
    static func stageForRestore(from url: URL) throws {
        let destination = StoreFiles.pendingRestoreURL
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.createDirectory(at: destination,
                                                withIntermediateDirectories: true)

        guard let file = ArchiveByteStream.fileStream(
                path: FilePath(url.path),
                mode: .readOnly,
                options: [],
                permissions: FilePermissions(rawValue: 0o644)),
              let decompression = ArchiveByteStream.decompressionStream(readingFrom: file),
              let decoder = ArchiveStream.decodeStream(readingFrom: decompression),
              let extractor = ArchiveStream.extractStream(extractingTo: FilePath(destination.path)) else {
            try? FileManager.default.removeItem(at: destination)
            throw Failure.cannotRead
        }

        do {
            _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
            try extractor.close()
            try decoder.close()
            try decompression.close()
            try file.close()
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw Failure.cannotRead
        }

        // Comprobado antes de dar la restauración por buena: si el archivo era
        // otra cosa, mejor decirlo ahora que al reiniciar y encontrarse la app
        // vacía.
        let store = destination.appending(path: StoreFiles.storeName)
        guard FileManager.default.fileExists(atPath: store.path) else {
            try? FileManager.default.removeItem(at: destination)
            throw Failure.notATreeCenterBackup
        }
    }

    // MARK: - Exportar para leerlo

    /// Los movimientos en CSV, que es lo que se abre en una hoja de cálculo.
    ///
    /// Punto decimal y no coma, y céntimos convertidos a euros: así lo entiende
    /// cualquier hoja sin tocar nada.
    static func movementsCSV(_ movements: [Movement]) -> String {
        var lines = ["fecha,tipo,concepto,cartera,seccion,destino,importe,recibo"]

        let order = movements.sorted { $0.date < $1.date }
        for movement in order {
            // A mano y con enteros: un formateador con el idioma del iPhone
            // escribiría «12,40», y una hoja de cálculo en inglés leería eso
            // como mil doscientos cuarenta.
            let euros = "\(movement.amountCents / 100).\(String(format: "%02d", movement.amountCents % 100))"

            lines.append([
                movement.date.formatted(.iso8601.year().month().day().dateSeparator(.dash)),
                movement.kind.rawValue,
                field(movement.concept),
                field(movement.wallet?.name ?? ""),
                field(movement.section?.name ?? ""),
                field(movement.destination?.name ?? ""),
                euros,
                movement.receipt == nil ? "no" : "si"
            ].joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    /// Un campo de CSV: entre comillas, y las comillas de dentro dobladas.
    private static func field(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func writeCSV(_ contents: String, named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        try? FileManager.default.removeItem(at: url)
        // UTF-8 con BOM: sin él, Excel en Windows se come los acentos.
        let bom = Data([0xEF, 0xBB, 0xBF])
        try (bom + Data(contents.utf8)).write(to: url)
        return url
    }

    static func weight(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
