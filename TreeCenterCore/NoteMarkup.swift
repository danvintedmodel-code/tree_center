import Foundation

// El formato de las notas. Se guardan como texto plano con cuatro marcas, que
// se escriben rápido con el teclado normal y se dibujan con formato:
//
//   # título
//   • lista        (también vale «- »)
//   [ ] casilla
//   [x] casilla marcada
//
// Texto plano a propósito: iOS 17 no trae un editor con formato, y así la nota
// sigue siendo legible tal cual en una copia o un CSV.

public enum NoteLine: Equatable, Sendable {
    case heading(String)
    case check(done: Bool, text: String)
    case bullet(String)
    case text(String)
    case blank
}

public enum NoteMarkup {

    public static func parse(_ text: String) -> [NoteLine] {
        text.components(separatedBy: "\n").map(line)
    }

    public static func line(_ raw: String) -> NoteLine {
        if raw.trimmingCharacters(in: .whitespaces).isEmpty { return .blank }
        if raw.hasPrefix("# ") { return .heading(String(raw.dropFirst(2))) }
        if raw.hasPrefix("[ ] ") { return .check(done: false, text: String(raw.dropFirst(4))) }
        if raw.hasPrefix("[x] ") || raw.hasPrefix("[X] ") {
            return .check(done: true, text: String(raw.dropFirst(4)))
        }
        if raw.hasPrefix("• ") || raw.hasPrefix("- ") { return .bullet(String(raw.dropFirst(2))) }
        return .text(raw)
    }

    /// Marca o desmarca la casilla de la línea `index`. Si esa línea no es una
    /// casilla, devuelve el texto sin tocar.
    public static func toggleCheck(in text: String, line index: Int) -> String {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(index) else { return text }

        let raw = lines[index]
        if raw.hasPrefix("[ ] ") {
            lines[index] = "[x] " + raw.dropFirst(4)
        } else if raw.hasPrefix("[x] ") || raw.hasPrefix("[X] ") {
            lines[index] = "[ ] " + raw.dropFirst(4)
        } else {
            return text
        }
        return lines.joined(separator: "\n")
    }

    /// Pone una marca al principio de la línea donde está el cursor. Es lo que
    /// hacen los botones de la barra del editor.
    ///
    /// - Returns: el texto nuevo y dónde queda el cursor.
    public static func insertMark(_ mark: String, in text: String, at cursor: Int) -> (text: String, cursor: Int) {
        let chars = Array(text)
        let safe = min(max(cursor, 0), chars.count)
        var start = safe
        while start > 0 && chars[start - 1] != "\n" { start -= 1 }

        let result = String(chars[..<start]) + mark + String(chars[start...])
        return (result, safe + mark.count)
    }

    /// Las casillas de una nota: hechas y en total.
    public static func checkCount(_ text: String) -> (done: Int, total: Int) {
        var done = 0, total = 0
        for case let .check(isDone, _) in parse(text) {
            total += 1
            if isDone { done += 1 }
        }
        return (done, total)
    }
}
