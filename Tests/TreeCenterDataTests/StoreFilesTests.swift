import Foundation
import XCTest
@testable import TreeCenterData

// Pruebas de lo único de la app que borra archivos del usuario.
//
// `applyPendingRestore` quita el almacén vivo antes de poner la copia encima.
// Si se equivoca, no sale un error: se pierden los datos. Así que aquí se
// comprueban las tres situaciones, y sobre todo la mala: una importación a
// medias **no** puede llevarse por delante lo que ya había.
//
// Todo pasa en una carpeta temporal, nunca en el Application Support de verdad.

final class StoreFilesTests: XCTestCase {

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appending(path: "tc-almacen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let folder { try? FileManager.default.removeItem(at: folder) }
        folder = nil
        super.tearDown()
    }

    // MARK: - Herramientas

    private func write(_ text: String, to name: String, in parent: URL? = nil) throws {
        let base = parent ?? folder!
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: base.appending(path: name))
    }

    private func read(_ name: String, in parent: URL? = nil) -> String? {
        let base = parent ?? folder!
        guard let data = try? Data(contentsOf: base.appending(path: name)) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private var incoming: URL {
        folder.appending(path: StoreFiles.restoreName)
    }

    /// Un almacén cualquiera ya puesto: base, wal, shm y una foto.
    private func writeCurrentStore() throws {
        try write("base vieja", to: StoreFiles.storeName)
        try write("wal viejo", to: StoreFiles.storeName + "-wal")
        try write("shm viejo", to: StoreFiles.storeName + "-shm")
        try write("foto vieja", to: "A1.bin",
                  in: folder.appending(path: StoreFiles.supportName))
    }

    // MARK: - Qué trozos hay

    func testSoloCuentaLosTrozosQueExisten() throws {
        XCTAssertEqual(StoreFiles.pieces(in: folder).count, 0)

        try write("base", to: StoreFiles.storeName)
        XCTAssertEqual(StoreFiles.pieces(in: folder).count, 1)

        try write("wal", to: StoreFiles.storeName + "-wal")
        try write("foto", to: "A1.bin", in: folder.appending(path: StoreFiles.supportName))
        XCTAssertEqual(StoreFiles.pieces(in: folder).count, 3)
    }

    func testLaCarpetaPendienteNoEsUnTrozoDelAlmacen() throws {
        try write("base", to: StoreFiles.storeName)
        try write("base nueva", to: StoreFiles.storeName, in: incoming)

        // Si la carpeta de restauración contara como trozo, el propio
        // `applyPendingRestore` la borraría antes de leerla.
        let names = StoreFiles.pieces(in: folder).map(\.lastPathComponent)
        XCTAssertFalse(names.contains(StoreFiles.restoreName))
    }

    // MARK: - Sin nada esperando

    func testSinCarpetaPendienteNoHaceNada() throws {
        try writeCurrentStore()

        XCTAssertFalse(StoreFiles.applyPendingRestore(in: folder))
        XCTAssertEqual(read(StoreFiles.storeName), "base vieja")
    }

    // MARK: - El caso peligroso

    func testUnaImportacionAMediasNoBorraLoQueYaHabia() throws {
        try writeCurrentStore()

        // Una carpeta pendiente sin el `.store` dentro: el `.aar` era otra cosa,
        // o la importación se cortó.
        try write("wal huerfano", to: StoreFiles.storeName + "-wal", in: incoming)

        XCTAssertFalse(StoreFiles.applyPendingRestore(in: folder))

        // Lo de antes, intacto. Esto es lo que de verdad importa de este archivo.
        XCTAssertEqual(read(StoreFiles.storeName), "base vieja")
        XCTAssertEqual(read(StoreFiles.storeName + "-wal"), "wal viejo")
        XCTAssertEqual(read("A1.bin", in: folder.appending(path: StoreFiles.supportName)),
                       "foto vieja")

        // Y la carpeta a medias, fuera: si se quedara, el siguiente arranque
        // volvería a intentarlo y a fallar para siempre.
        XCTAssertFalse(FileManager.default.fileExists(atPath: incoming.path))
    }

    func testCarpetaPendienteVaciaSeTira() throws {
        try FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: true)

        XCTAssertFalse(StoreFiles.applyPendingRestore(in: folder))
        XCTAssertFalse(FileManager.default.fileExists(atPath: incoming.path))
    }

    // MARK: - Una restauración de verdad

    func testRestauraLaBaseYLasFotos() throws {
        try writeCurrentStore()

        try write("base nueva", to: StoreFiles.storeName, in: incoming)
        try write("wal nuevo", to: StoreFiles.storeName + "-wal", in: incoming)
        try write("foto nueva", to: "B2.bin",
                  in: incoming.appending(path: StoreFiles.supportName))

        XCTAssertTrue(StoreFiles.applyPendingRestore(in: folder))

        XCTAssertEqual(read(StoreFiles.storeName), "base nueva")
        XCTAssertEqual(read(StoreFiles.storeName + "-wal"), "wal nuevo")

        let photos = folder.appending(path: StoreFiles.supportName)
        XCTAssertEqual(read("B2.bin", in: photos), "foto nueva")

        // Las fotos viejas se van con la carpeta vieja: una restauración deja el
        // almacén de la copia, no una mezcla de los dos.
        XCTAssertNil(read("A1.bin", in: photos))

        // El shm viejo tampoco se queda: describe un wal que ya no existe.
        XCTAssertNil(read(StoreFiles.storeName + "-shm"))

        XCTAssertFalse(FileManager.default.fileExists(atPath: incoming.path))
    }

    func testRestaurarDosVecesNoRepiteLaPrimera() throws {
        try write("base nueva", to: StoreFiles.storeName, in: incoming)
        XCTAssertTrue(StoreFiles.applyPendingRestore(in: folder))

        // La segunda vuelta no tiene nada que hacer: la carpeta ya no está.
        XCTAssertFalse(StoreFiles.applyPendingRestore(in: folder))
        XCTAssertEqual(read(StoreFiles.storeName), "base nueva")
    }
}
