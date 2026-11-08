import CoreGraphics
import Foundation

// Comparar dos trazos hechos a mano.
//
// Esto vive aparte del resto de la app a propósito: no importa SwiftUI ni UIKit,
// así que se puede probar sola. Es la única pieza del Acceso con lógica de verdad,
// y la única que puede fallar en silencio, así que es la que lleva tests.
//
// Una Z nunca sale igual dos veces, así que no se comparan los puntos crudos:
// se normaliza la forma y se mide cuánto se parecen. Qué se ignora y qué no,
// que es donde está la seguridad:
//
//   Se ignora  el tamaño del trazo y dónde lo dibujaste dentro del lienzo.
//   NO se ignora la rotación: una Z tumbada es otro trazo, y no abre.
//   NO se ignora el orden: la misma forma dibujada al revés es otro trazo.
//   NO se ignora cuántos trazos son: dos palos sueltos no son una X.

public enum StrokeTolerance: String, Codable, CaseIterable, Identifiable, Sendable {
    case strict, normal, loose

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .strict: return "Estricto"
        case .normal: return "Normal"
        case .loose: return "Flexible"
        }
    }

    public var minimumScore: Double {
        switch self {
        case .strict: return 0.88
        case .normal: return 0.80
        case .loose: return 0.70
        }
    }
}

/// Un trazo ya normalizado: centrado en el origen y escalado a una caja de 1 × 1.
public struct StrokePattern: Codable, Equatable, Sendable {
    public var strokes: [[CGPoint]]

    public init(strokes: [[CGPoint]]) {
        self.strokes = strokes
    }
}

public enum StrokeMatcher {
    /// Puntos por trazo tras el remuestreo. 32 basta para una letra y es barato.
    public static let samplesPerStroke = 32

    /// Distancia media a partir de la cual dos formas no se parecen en nada.
    /// Los puntos viven en una caja de lado 1, así que 0.45 ya es "otra cosa".
    private static let noMatchDistance: CGFloat = 0.45

    /// Lado mínimo, en puntos de pantalla, para que lo dibujado cuente como trazo.
    private static let minimumSide: CGFloat = 8

    /// Convierte los puntos crudos del dedo en un patrón comparable.
    /// Devuelve nil si lo dibujado no da para un trazo (un toque suelto, por ejemplo).
    public static func normalise(_ raw: [[CGPoint]]) -> StrokePattern? {
        let usable = raw.filter { $0.count >= 2 }
        guard !usable.isEmpty else { return nil }

        var strokes = usable.map { resample($0, to: samplesPerStroke) }
        let all = strokes.flatMap { $0 }
        guard !all.isEmpty else { return nil }

        let xs = all.map(\.x), ys = all.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return nil }

        // Escalado uniforme: conservar la proporción es lo que impide que una raya
        // vertical y una horizontal acaben siendo el mismo patrón.
        let side = max(maxX - minX, maxY - minY)
        guard side > minimumSide else { return nil }

        let count = CGFloat(all.count)
        let cx = all.reduce(CGFloat.zero) { $0 + $1.x } / count
        let cy = all.reduce(CGFloat.zero) { $0 + $1.y } / count

        for i in strokes.indices {
            for j in strokes[i].indices {
                strokes[i][j] = CGPoint(x: (strokes[i][j].x - cx) / side,
                                        y: (strokes[i][j].y - cy) / side)
            }
        }
        return StrokePattern(strokes: strokes)
    }

    /// 1 = idénticos, 0 = no se parecen. Distinto número de trazos es 0 directo.
    public static func score(_ a: StrokePattern, _ b: StrokePattern) -> Double {
        guard a.strokes.count == b.strokes.count else { return 0 }

        var total: CGFloat = 0
        var n = 0
        for (sa, sb) in zip(a.strokes, b.strokes) {
            guard sa.count == sb.count else { return 0 }
            for (pa, pb) in zip(sa, sb) {
                total += distance(pa, pb)
                n += 1
            }
        }
        guard n > 0 else { return 0 }

        let mean = total / CGFloat(n)
        return Double(max(0, 1 - mean / noMatchDistance))
    }

    public static func matches(_ attempt: StrokePattern,
                               template: StrokePattern,
                               tolerance: StrokeTolerance) -> Bool {
        score(attempt, template) >= tolerance.minimumScore
    }

    // MARK: - Remuestreo

    /// Reparte `count` puntos equidistantes a lo largo del trazo.
    /// Así da igual que dibujes despacio o deprisa: solo cuenta la forma.
    public static func resample(_ points: [CGPoint], to count: Int) -> [CGPoint] {
        guard points.count > 1, count > 1 else { return points }

        let total = pathLength(points)
        guard total > 0 else { return Array(repeating: points[0], count: count) }

        let interval = total / CGFloat(count - 1)
        var working = points
        var result = [points[0]]
        var accumulated: CGFloat = 0
        var i = 1

        while i < working.count {
            let d = distance(working[i - 1], working[i])
            if accumulated + d >= interval, d > 0 {
                let t = (interval - accumulated) / d
                let cut = CGPoint(
                    x: working[i - 1].x + t * (working[i].x - working[i - 1].x),
                    y: working[i - 1].y + t * (working[i].y - working[i - 1].y)
                )
                result.append(cut)
                working.insert(cut, at: i)
                accumulated = 0
            } else {
                accumulated += d
            }
            i += 1
        }

        // El redondeo puede dejar el último punto fuera; se completa con el final real.
        while result.count < count, let last = points.last { result.append(last) }
        return Array(result.prefix(count))
    }

    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<points.count { total += distance(points[i - 1], points[i]) }
        return total
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
