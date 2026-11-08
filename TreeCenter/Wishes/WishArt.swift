import SwiftUI
import TreeCenterData

// Los dibujos de Caprichos y Viajes, en línea de 1,3 px.
//
// Van como `Path` y no como imágenes por dos razones: pesan cero y el grosor
// del trazo no engorda al escalar, que es justo lo que arruina un dibujo de
// línea cuando se hace con PNG o con `scaleEffect`.
//
// Son de boceto, igual que los del lienzo de diseño: fijan el estilo para que
// el ilustrador sepa qué encargar, no son los definitivos.

struct LineArt: View {
    /// El espacio en el que están escritas las coordenadas.
    let canvas: CGSize
    let color: Color
    var lineWidth: CGFloat = 1.3
    let draw: (inout Path) -> Void

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / canvas.width, geo.size.height / canvas.height)
            let dx = (geo.size.width - canvas.width * scale) / 2
            let dy = (geo.size.height - canvas.height * scale) / 2

            Path { path in draw(&path) }
                .applying(CGAffineTransform(scaleX: scale, y: scale)
                    .concatenating(CGAffineTransform(translationX: dx, y: dy)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth,
                                                  lineCap: .round,
                                                  lineJoin: .round))
        }
    }
}

private func line(_ path: inout Path, _ points: [CGPoint], close: Bool = false) {
    guard let first = points.first else { return }
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    if close { path.closeSubpath() }
}

private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

// MARK: - Caprichos

extension WishKind {
    var artCanvas: CGSize { CGSize(width: 100, height: 70) }

    @MainActor
    func art(_ color: Color) -> some View {
        LineArt(canvas: artCanvas, color: color, draw: drawing)
    }

    var drawing: (inout Path) -> Void {
        switch self {
        case .architecture: return Self.architecture
        case .sport: return Self.sport
        case .gifts: return Self.gifts
        case .books: return Self.books
        case .travel: return Self.travel
        }
    }

    private static func architecture(_ path: inout Path) {
        line(&path, [p(8, 62), p(92, 62)])
        line(&path, [p(18, 62), p(18, 28), p(36, 28), p(36, 62)])
        line(&path, [p(36, 62), p(36, 16), p(57, 16), p(57, 62)])
        line(&path, [p(57, 62), p(57, 34), p(78, 34), p(78, 62)])
        for y in [36.0, 46.0] { line(&path, [p(24, y), p(30, y)]) }
        for y in [26.0, 38.0, 50.0] { line(&path, [p(42, y), p(51, y)]) }
        for y in [42.0, 52.0] { line(&path, [p(63, y), p(73, y)]) }
    }

    private static func sport(_ path: inout Path) {
        path.addEllipse(in: CGRect(x: 27, y: 12, width: 46, height: 46))
        line(&path, [p(50, 20), p(41, 27), p(44.5, 38), p(55.5, 38), p(59, 27)], close: true)
        line(&path, [p(50, 12), p(50, 20)])
        line(&path, [p(28, 28), p(41, 27)])
        line(&path, [p(72, 28), p(59, 27)])
        line(&path, [p(36, 54), p(44.5, 38)])
        line(&path, [p(64, 54), p(55.5, 38)])
    }

    private static func gifts(_ path: inout Path) {
        line(&path, [p(24, 32), p(76, 32), p(76, 62), p(24, 62)], close: true)
        line(&path, [p(19, 24), p(81, 24), p(81, 32), p(19, 32)], close: true)
        line(&path, [p(50, 24), p(50, 62)])
        path.move(to: p(50, 24))
        path.addCurve(to: p(33.5, 24), control1: p(43, 13), control2: p(31, 16))
        path.move(to: p(50, 24))
        path.addCurve(to: p(66.5, 24), control1: p(57, 13), control2: p(69, 16))
    }

    private static func books(_ path: inout Path) {
        line(&path, [p(20, 60), p(80, 60)])
        line(&path, [p(26, 60), p(26, 26), p(35, 26), p(35, 60)], close: true)
        line(&path, [p(37, 60), p(37, 20), p(47, 20), p(47, 60)], close: true)
        line(&path, [p(49, 60), p(49, 30), p(58, 30), p(58, 60)], close: true)
        line(&path, [p(60, 60), p(65, 28), p(74, 30), p(69, 60)], close: true)
        line(&path, [p(28, 32), p(33, 32)])
        line(&path, [p(39, 26), p(45, 26)])
    }

    private static func travel(_ path: inout Path) {
        path.addEllipse(in: CGRect(x: 66, y: 9, width: 16, height: 16))
        line(&path, [p(8, 56), p(28, 26), p(41, 41), p(56, 20), p(78, 56)])
        line(&path, [p(6, 56), p(94, 56)])
        line(&path, [p(28, 26), p(34, 33), p(29, 36)], close: true)
    }
}

// MARK: - Viajes

/// Tres paisajes. Sin fotos reales, un dibujo por lugar sería mentir; tres
/// variantes repartidas por el nombre al menos evitan que catorce tarjetas
/// seguidas sean idénticas.
enum PlaceArt: Int, CaseIterable {
    case mountains, pagoda, coast

    static func forName(_ name: String) -> PlaceArt {
        let index = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % allCases.count
        return allCases[index]
    }

    var canvas: CGSize { CGSize(width: 330, height: 200) }

    var drawing: (inout Path) -> Void {
        switch self {
        case .mountains: return Self.mountains
        case .pagoda: return Self.pagoda
        case .coast: return Self.coast
        }
    }

    private static func mountains(_ path: inout Path) {
        line(&path, [p(0, 158), p(52, 92), p(88, 128), p(134, 64), p(182, 144),
                     p(222, 100), p(264, 144), p(330, 94)])
        line(&path, [p(134, 64), p(148, 87), p(138, 92), p(126, 82)], close: true)
        line(&path, [p(0, 168), p(70, 128), p(120, 158), p(180, 122), p(240, 160), p(330, 124)])
        line(&path, [p(0, 186), p(330, 186)])
        line(&path, [p(30, 186), p(48, 186), p(39, 162)], close: true)
        line(&path, [p(268, 186), p(284, 186), p(276, 165)], close: true)
    }

    private static func pagoda(_ path: inout Path) {
        path.addEllipse(in: CGRect(x: 267, y: 31, width: 30, height: 30))
        line(&path, [p(60, 162), p(212, 162)])
        line(&path, [p(118, 162), p(118, 142), p(148, 142), p(148, 162)])
        path.move(to: p(98, 142)); path.addQuadCurve(to: p(168, 142), control: p(133, 130))
        line(&path, [p(122, 142), p(122, 127), p(144, 127), p(144, 142)])
        path.move(to: p(106, 127)); path.addQuadCurve(to: p(164, 127), control: p(135, 117))
        line(&path, [p(126, 127), p(126, 114), p(140, 114), p(140, 127)])
        path.move(to: p(112, 114)); path.addQuadCurve(to: p(158, 114), control: p(135, 105))
        line(&path, [p(133, 114), p(133, 98)])
        line(&path, [p(232, 162), p(232, 116)])
        line(&path, [p(272, 162), p(272, 116)])
        path.move(to: p(222, 116)); path.addQuadCurve(to: p(282, 116), control: p(252, 110))
        line(&path, [p(228, 127), p(276, 127)])
        line(&path, [p(0, 186), p(330, 186)])
    }

    private static func coast(_ path: inout Path) {
        path.addEllipse(in: CGRect(x: 245, y: 36, width: 26, height: 26))
        line(&path, [p(0, 120), p(58, 78), p(104, 118)])
        line(&path, [p(96, 128), p(330, 128)])
        for y in stride(from: 142.0, through: 178.0, by: 12.0) {
            path.move(to: p(20, y))
            path.addQuadCurve(to: p(120, y), control: p(70, y - 7))
            path.move(to: p(140, y + 4))
            path.addQuadCurve(to: p(250, y + 4), control: p(195, y - 3))
        }
        line(&path, [p(58, 128), p(58, 100)])
        line(&path, [p(48, 104), p(58, 96), p(68, 104)])
    }
}
