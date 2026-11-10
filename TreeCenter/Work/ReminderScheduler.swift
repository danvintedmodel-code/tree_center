import Foundation
import TreeCenterData
import UserNotifications

// Los avisos del propio iPhone.
//
// Son notificaciones locales: las programa el móvil y llegan aunque la app esté
// cerrada, sin internet y sin cuenta. Funcionan instalando la app gratis, que es
// lo que importa aquí: las notificaciones remotas (push) sí necesitan el
// programa de pago de Apple, pero estas no.
//
// Recibe datos sueltos y no el modelo: un objeto de SwiftData no debe viajar
// fuera del hilo donde vive, y el centro de notificaciones trabaja en el suyo.

enum ReminderScheduler {

    /// Pide permiso la primera vez y devuelve si lo hay. Sin permiso los avisos
    /// se guardan igual, pero el iPhone no los enseña.
    static func ensurePermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func schedule(id: String, title: String, body: String,
                         kind: ReminderKind, hour: Int, minute: Int, date: Date?) {
        var when = DateComponents()
        when.hour = hour
        when.minute = minute

        if kind == .once {
            // Un aviso de un día concreto sin fecha no tiene cuándo sonar.
            guard let date else { return }
            let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
            when.year = day.year
            when.month = day.month
            when.day = day.day
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: kind == .daily)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        // Mismo identificador = sustituye al anterior, así reprogramar no duplica.
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Lo que se lee en el aviso: «cada día a las 21:30», «14 nov a las 19:00».
    static func describe(kind: ReminderKind, hour: Int, minute: Int, date: Date?) -> String {
        let time = String(format: "%d:%02d", hour, minute)
        if kind == .daily { return "cada día a las \(time)" }
        guard let date else { return "a las \(time)" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM"
        return "\(f.string(from: date)) a las \(time)"
    }
}
