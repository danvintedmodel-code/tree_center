import CoreGraphics
import XCTest
@testable import TreeCenterCore

// Lo que estas pruebas defienden no es "el código corre": es la promesa de seguridad
// del Acceso. Si alguna de las tres últimas se pone en verde al revés, el trazo ha
// dejado de ser una contraseña y se ha convertido en un gesto cualquiera.

final class StrokeMatcherTests: XCTestCase {

    // MARK: - Material de dibujo

    /// Una Z: horizontal, diagonal, horizontal.
    private let zedCorners = [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 100, y: 0),
        CGPoint(x: 0, y: 100),
        CGPoint(x: 100, y: 100)
    ]

    /// Convierte esquinas en una línea densa, como la que deja un dedo.
    private func polyline(_ corners: [CGPoint], perSegment: Int = 40) -> [CGPoint] {
        guard corners.count > 1 else { return corners }
        var out = [corners[0]]
        for i in 1..<corners.count {
            let a = corners[i - 1], b = corners[i]
            for step in 1...perSegment {
                let t = CGFloat(step) / CGFloat(perSegment)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t,
                                   y: a.y + (b.y - a.y) * t))
            }
        }
        return out
    }

    private func transform(_ points: [CGPoint], scale: CGFloat, dx: CGFloat, dy: CGFloat) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * scale + dx, y: $0.y * scale + dy) }
    }

    private func rotated90(_ points: [CGPoint]) -> [CGPoint] {
        points.map { CGPoint(x: -$0.y, y: $0.x) }
    }

    private func pattern(_ strokes: [[CGPoint]]) throws -> StrokePattern {
        try XCTUnwrap(StrokeMatcher.normalise(strokes), "El trazo debería ser válido")
    }

    // MARK: - Lo que sí tiene que abrir

    func testMismaFormaMasGrandeYMovidaAbre() throws {
        let original = try pattern([polyline(zedCorners)])
        let otraVez = try pattern([transform(polyline(zedCorners), scale: 2.4, dx: 57, dy: -31)])

        let score = StrokeMatcher.score(otraVez, original)
        print("[trazo] escalado y movido: \(score)")
        XCTAssertGreaterThan(score, 0.95, "El tamaño y la posición no deberían contar")
        XCTAssertTrue(StrokeMatcher.matches(otraVez, template: original, tolerance: .strict))
    }

    func testTemblorPequenoSigueAbriendo() throws {
        let original = try pattern([polyline(zedCorners)])

        // Un pulso humano es una ondulación lenta, no un diente de sierra: unos 3 pt
        // de amplitud sobre un trazo de 100, con un periodo de medio centenar de
        // muestras. Un zigzag en cada muestra no es temblor, es garabatear.
        var wobbly = polyline(zedCorners)
        for i in wobbly.indices {
            let wobble = CGFloat(sin(Double(i) / 9.0)) * 3
            wobbly[i] = CGPoint(x: wobbly[i].x + wobble, y: wobbly[i].y - wobble)
        }

        let score = StrokeMatcher.score(try pattern([wobbly]), original)
        print("[trazo] con temblor: \(score)")
        XCTAssertGreaterThan(score, 0.85, "El margen para un pulso normal es demasiado justo")
        XCTAssertTrue(StrokeMatcher.matches(try pattern([wobbly]),
                                            template: original,
                                            tolerance: .normal),
                      "Un pulso normal no puede dejarte fuera de tu propia app")
    }

    // MARK: - Lo que NO tiene que abrir

    func testLaMismaFormaGiradaNoAbre() throws {
        let original = try pattern([polyline(zedCorners)])
        let tumbada = try pattern([rotated90(polyline(zedCorners))])

        XCTAssertFalse(StrokeMatcher.matches(tumbada, template: original, tolerance: .loose),
                       "Una Z tumbada es otro trazo: la rotación cuenta")
    }

    func testDibujarloAlRevesNoAbre() throws {
        let original = try pattern([polyline(zedCorners)])
        let alReves = try pattern([polyline(zedCorners).reversed()])

        XCTAssertFalse(StrokeMatcher.matches(alReves, template: original, tolerance: .loose),
                       "El orden del recorrido cuenta")
    }

    func testPartirloEnDosTrazosNoAbre() throws {
        let entero = try pattern([polyline(zedCorners)])
        let partido = try pattern([
            polyline(Array(zedCorners[0...1])),
            polyline(Array(zedCorners[1...3]))
        ])

        XCTAssertEqual(StrokeMatcher.score(partido, entero), 0,
                       "Distinto número de trazos es un no inmediato")
    }

    // MARK: - Bordes

    func testUnToqueNoEsUnTrazo() {
        let toque = [[CGPoint(x: 40, y: 40), CGPoint(x: 41, y: 42), CGPoint(x: 40, y: 43)]]
        XCTAssertNil(StrokeMatcher.normalise(toque),
                     "Un roce de tres píxeles no puede contar como intento")
    }

    func testLienzoVacioNoDaPatron() {
        XCTAssertNil(StrokeMatcher.normalise([]))
        XCTAssertNil(StrokeMatcher.normalise([[CGPoint(x: 10, y: 10)]]))
    }

    func testElRemuestreoDevuelveLosPuntosPedidos() {
        let points = polyline(zedCorners)
        XCTAssertEqual(StrokeMatcher.resample(points, to: 32).count, 32)
        XCTAssertEqual(StrokeMatcher.resample(points, to: 7).count, 7)
    }

    func testTodoQuedaDentroDeLaCajaNormalizada() throws {
        let p = try pattern([transform(polyline(zedCorners), scale: 3.1, dx: -220, dy: 90)])
        for stroke in p.strokes {
            for point in stroke {
                XCTAssertLessThanOrEqual(abs(point.x), 1.0)
                XCTAssertLessThanOrEqual(abs(point.y), 1.0)
            }
        }
    }
}
