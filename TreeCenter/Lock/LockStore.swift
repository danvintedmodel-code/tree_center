import Foundation
import Security
import TreeCenterCore

// Dónde vive el trazo guardado.
//
// Va al Keychain con `WhenPasscodeSetThisDeviceOnly`: no sale del iPhone, no entra
// en la copia de iCloud y deja de existir si quitas el código del teléfono.
//
// Se guarda la plantilla, no un hash. Un hash es imposible aquí: el trazo nunca
// sale igual dos veces, así que hay que poder medir el parecido contra algo.
// Lo que protege el secreto es el Keychain, no un cifrado nuestro.

struct LockSecret: Codable {
    var pattern: StrokePattern
    var tolerance: StrokeTolerance
}

enum LockStore {
    private static let service = "center.tree.lock"
    private static let account = "stroke-pattern"

    enum StoreError: Error { case encodingFailed, keychainFailed(OSStatus) }

    static var hasPattern: Bool { load() != nil }

    static func save(_ secret: LockSecret) throws {
        guard let data = try? JSONEncoder().encode(secret) else { throw StoreError.encodingFailed }

        // Borrar antes de escribir: SecItemUpdate con atributos de acceso da más guerra.
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.keychainFailed(status) }
    }

    static func load() -> LockSecret? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }

        return try? JSONDecoder().decode(LockSecret.self, from: data)
    }

    @discardableResult
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
