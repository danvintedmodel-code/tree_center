import Foundation
import UserNotifications

// Cuándo caduca esta instalación, y los avisos que dependen de eso.
//
// Instalada gratis (con Sideloadly y un Apple ID sin programa de pago), la firma
// dura 7 días. La fecha exacta no hay que adivinarla: va escrita dentro de la
// propia app, en `embedded.mobileprovision`, que es lo que Apple deja al firmar.
// Ese archivo es un plist envuelto en una firma; basta con sacar el plist de
// dentro y leer `ExpirationDate`.
//
// Instalada desde Xcode en el simulador no hay archivo, y entonces no hay fecha.

enum InstallInfo {

    struct Signature: Equatable {
        let issued: Date?
        let expires: Date
    }

    /// Se lee una vez: el archivo no cambia mientras la app está instalada.
    static let signature: Signature? = readProfile()

    private static func readProfile() -> Signature? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }

        let plist = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let dict = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let expires = dict["ExpirationDate"] as? Date
        else { return nil }

        return Signature(issued: dict["CreationDate"] as? Date, expires: expires)
    }

    /// Días que quedan, contando hoy como el día cero. Negativo si ya caducó.
    static func daysLeft(now: Date = .now) -> Int? {
        guard let expires = signature?.expires else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: expires)).day
    }

    static func describe(now: Date = .now) -> String {
        guard let left = daysLeft(now: now) else { return "Sin fecha de caducidad" }
        switch left {
        case ..<0: return "Caducada"
        case 0: return "Caduca hoy"
        case 1: return "Caduca mañana"
        default: return "Caduca en \(left) días"
        }
    }

    // MARK: - Avisos

    static let expiryWarnKey = "tc.expiryWarn"
    static let backupWarnKey = "tc.backupWarn"

    private static let expiryID = "tc.expiry"
    private static let backupID = "tc.backup"

    /// El aviso del día antes de caducar, a las 10:00. Se reprograma en cada
    /// arranque: tras renovar la firma, la fecha cambia.
    static func scheduleExpiryWarning(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [expiryID])

        guard enabled, let expires = signature?.expires,
              let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: expires),
              dayBefore > .now else { return }

        var when = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
        when.hour = 10
        when.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Tree Center caduca mañana"
        content.body = "Renuévala desde el PC con el iPhone conectado. Tus datos no se pierden."
        content.sound = .default

        center.add(UNNotificationRequest(identifier: expiryID, content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)))
    }

    /// Cada domingo a las 11:00: sin iCloud, la copia es lo que te salva si
    /// pierdes el móvil.
    static func scheduleBackupReminder(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [backupID])
        guard enabled else { return }

        var when = DateComponents()
        when.weekday = 1
        when.hour = 11
        when.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Copia de Tree Center"
        content.body = "Ajustes → Guardar una copia, y guárdala en iCloud Drive."
        content.sound = .default

        center.add(UNNotificationRequest(identifier: backupID, content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)))
    }
}
