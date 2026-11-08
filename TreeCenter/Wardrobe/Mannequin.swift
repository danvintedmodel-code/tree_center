import SwiftUI
import TreeCenterData

// El maniquí, en línea, dibujado con Path.
//
// No es el de verdad. El del diseño gira 360° y lleva la ropa como mallas
// atadas a un esqueleto, y eso es RealityKit y trabajo de modelado que todavía
// no existe. Esto es el sustituto honesto: una figura de frente que marca en
// musgo lo que llevas puesto por categoría.
//
// Cuando entre el modelo 3D, esta vista se cambia por la otra y nada más de la
// pantalla se entera.

struct Mannequin: View {
    let worn: Set<GarmentCategory>
    var accent: Color = TCColor.moss

    private let canvas = CGSize(width: 160, height: 360)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / canvas.width, geo.size.height / canvas.height)
            let dx = (geo.size.width - canvas.width * scale) / 2
            let dy = (geo.size.height - canvas.height * scale) / 2
            let t = CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: dx, y: dy))

            ZStack {
                body(hiddenTorso: coversTorso).applying(t)
                    .stroke(TCColor.textSoft, style: stroke(1.5))

                ForEach(Array(worn).sorted { $0.rawValue < $1.rawValue }, id: \.self) { category in
                    if let piece = garmentPath(category) {
                        piece.applying(t).fill(accent.opacity(0.11))
                        piece.applying(t).stroke(accent, style: stroke(1.5))
                    }
                }

                stand.applying(t).stroke(TCColor.lineStrong, style: stroke(1.3))
            }
        }
        .accessibilityLabel(label)
    }

    private func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    private var coversTorso: Bool {
        worn.contains(.hoodies) || worn.contains(.shirts)
    }

    private var label: String {
        worn.isEmpty
            ? "Maniquí sin ropa"
            : "Maniquí con " + worn.map { $0.label.lowercased() }.sorted().joined(separator: ", ")
    }

    // MARK: - El cuerpo

    private func body(hiddenTorso: Bool) -> Path {
        var p = Path()

        p.addEllipse(in: CGRect(x: 61.5, y: 16.5, width: 37, height: 47))
        p.move(to: CGPoint(x: 80, y: 63.5)); p.addLine(to: CGPoint(x: 80, y: 74))

        if !hiddenTorso {
            p.move(to: CGPoint(x: 54, y: 84))
            p.addQuadCurve(to: CGPoint(x: 106, y: 84), control: CGPoint(x: 80, y: 75))
            p.addLine(to: CGPoint(x: 101, y: 152))
            p.addQuadCurve(to: CGPoint(x: 59, y: 152), control: CGPoint(x: 80, y: 159))
            p.closeSubpath()

            p.move(to: CGPoint(x: 54, y: 86))
            p.addLine(to: CGPoint(x: 42, y: 148))
            p.move(to: CGPoint(x: 106, y: 86))
            p.addLine(to: CGPoint(x: 118, y: 148))
        }

        // Antebrazos y manos: se ven lleves lo que lleves.
        p.move(to: CGPoint(x: 44, y: 139)); p.addLine(to: CGPoint(x: 40, y: 174))
        p.move(to: CGPoint(x: 116, y: 139)); p.addLine(to: CGPoint(x: 120, y: 174))
        p.addEllipse(in: CGRect(x: 34.4, y: 173.8, width: 9.2, height: 12.4))
        p.addEllipse(in: CGRect(x: 116.4, y: 173.8, width: 9.2, height: 12.4))

        if !worn.contains(.trousers) {
            p.move(to: CGPoint(x: 67, y: 190))
            p.addLine(to: CGPoint(x: 62, y: 250)); p.addLine(to: CGPoint(x: 60, y: 306))
            p.move(to: CGPoint(x: 93, y: 190))
            p.addLine(to: CGPoint(x: 98, y: 250)); p.addLine(to: CGPoint(x: 100, y: 306))
        }

        if !worn.contains(.shoes) {
            p.move(to: CGPoint(x: 52, y: 306)); p.addLine(to: CGPoint(x: 68, y: 306))
            p.move(to: CGPoint(x: 92, y: 306)); p.addLine(to: CGPoint(x: 108, y: 306))
        }

        return p
    }

    private var stand: Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: 32, y: 313, width: 96, height: 18))
        return p
    }

    // MARK: - La ropa

    private func garmentPath(_ category: GarmentCategory) -> Path? {
        var p = Path()

        switch category {
        case .caps:
            p.move(to: CGPoint(x: 58, y: 34))
            p.addQuadCurve(to: CGPoint(x: 102, y: 34), control: CGPoint(x: 80, y: 8))
            p.closeSubpath()
            p.move(to: CGPoint(x: 58, y: 34)); p.addLine(to: CGPoint(x: 44, y: 37))

        case .necklaces:
            p.move(to: CGPoint(x: 66, y: 78))
            p.addQuadCurve(to: CGPoint(x: 94, y: 78), control: CGPoint(x: 80, y: 100))

        case .hoodies:
            p.move(to: CGPoint(x: 50, y: 80))
            p.addQuadCurve(to: CGPoint(x: 110, y: 80), control: CGPoint(x: 80, y: 68))
            p.addLine(to: CGPoint(x: 120, y: 136)); p.addLine(to: CGPoint(x: 106, y: 141))
            p.addLine(to: CGPoint(x: 103, y: 186))
            p.addQuadCurve(to: CGPoint(x: 57, y: 186), control: CGPoint(x: 80, y: 194))
            p.addLine(to: CGPoint(x: 54, y: 141)); p.addLine(to: CGPoint(x: 40, y: 136))
            p.closeSubpath()
            p.move(to: CGPoint(x: 63, y: 76))
            p.addQuadCurve(to: CGPoint(x: 97, y: 76), control: CGPoint(x: 80, y: 93))

        case .shirts:
            p.move(to: CGPoint(x: 52, y: 82))
            p.addQuadCurve(to: CGPoint(x: 108, y: 82), control: CGPoint(x: 80, y: 71))
            p.addLine(to: CGPoint(x: 116, y: 124)); p.addLine(to: CGPoint(x: 104, y: 129))
            p.addLine(to: CGPoint(x: 101, y: 176))
            p.addQuadCurve(to: CGPoint(x: 59, y: 176), control: CGPoint(x: 80, y: 183))
            p.addLine(to: CGPoint(x: 56, y: 129)); p.addLine(to: CGPoint(x: 44, y: 124))
            p.closeSubpath()

        case .trousers:
            p.move(to: CGPoint(x: 58, y: 186))
            p.addLine(to: CGPoint(x: 102, y: 186))
            p.addLine(to: CGPoint(x: 99, y: 250)); p.addLine(to: CGPoint(x: 97, y: 302))
            p.addLine(to: CGPoint(x: 86, y: 302)); p.addLine(to: CGPoint(x: 80, y: 232))
            p.addLine(to: CGPoint(x: 74, y: 302)); p.addLine(to: CGPoint(x: 63, y: 302))
            p.addLine(to: CGPoint(x: 61, y: 250))
            p.closeSubpath()

        case .socks:
            p.move(to: CGPoint(x: 62, y: 286)); p.addLine(to: CGPoint(x: 74, y: 286))
            p.addLine(to: CGPoint(x: 73, y: 304)); p.addLine(to: CGPoint(x: 61, y: 304))
            p.closeSubpath()
            p.move(to: CGPoint(x: 86, y: 286)); p.addLine(to: CGPoint(x: 98, y: 286))
            p.addLine(to: CGPoint(x: 99, y: 304)); p.addLine(to: CGPoint(x: 87, y: 304))
            p.closeSubpath()

        case .shoes:
            p.move(to: CGPoint(x: 58, y: 298))
            p.addLine(to: CGPoint(x: 72, y: 298)); p.addLine(to: CGPoint(x: 74, y: 310))
            p.addLine(to: CGPoint(x: 50, y: 310)); p.addLine(to: CGPoint(x: 52, y: 300))
            p.closeSubpath()
            p.move(to: CGPoint(x: 88, y: 298))
            p.addLine(to: CGPoint(x: 102, y: 298)); p.addLine(to: CGPoint(x: 108, y: 300))
            p.addLine(to: CGPoint(x: 110, y: 310)); p.addLine(to: CGPoint(x: 86, y: 310))
            p.closeSubpath()
        }

        return p.isEmpty ? nil : p
    }
}

// MARK: - Iconos de categoría

extension GarmentCategory {
    var canvas: CGSize { CGSize(width: 24, height: 24) }

    /// Los mismos trazos del lienzo de diseño, en Path. Sin SF Symbols aquí:
    /// estos siete son los que más se repiten y conviene que sean los nuestros.
    var drawing: (inout Path) -> Void {
        switch self {
        case .caps: return { p in
            p.move(to: CGPoint(x: 4, y: 15.5)); p.addLine(to: CGPoint(x: 18.5, y: 15.5))
            p.move(to: CGPoint(x: 5.5, y: 15.5))
            p.addQuadCurve(to: CGPoint(x: 18.5, y: 15.5), control: CGPoint(x: 12, y: 2.5))
            p.move(to: CGPoint(x: 18.5, y: 15.5))
            p.addQuadCurve(to: CGPoint(x: 17.8, y: 18.7), control: CGPoint(x: 22, y: 17))
        }
        case .necklaces: return { p in
            p.move(to: CGPoint(x: 6, y: 4.5))
            p.addQuadCurve(to: CGPoint(x: 18, y: 4.5), control: CGPoint(x: 12, y: 19))
            p.addEllipse(in: CGRect(x: 9.2, y: 14.6, width: 5.6, height: 5.6))
        }
        case .hoodies: return { p in
            p.move(to: CGPoint(x: 8.5, y: 4.2)); p.addLine(to: CGPoint(x: 4, y: 7.4))
            p.addLine(to: CGPoint(x: 6, y: 10.8)); p.addLine(to: CGPoint(x: 8.1, y: 9.6))
            p.addLine(to: CGPoint(x: 8.1, y: 19.8)); p.addLine(to: CGPoint(x: 15.9, y: 19.8))
            p.addLine(to: CGPoint(x: 15.9, y: 9.6)); p.addLine(to: CGPoint(x: 18, y: 10.8))
            p.addLine(to: CGPoint(x: 20, y: 7.4)); p.addLine(to: CGPoint(x: 15.5, y: 4.2))
            p.closeSubpath()
            p.move(to: CGPoint(x: 9.6, y: 4.4))
            p.addQuadCurve(to: CGPoint(x: 14.4, y: 4.4), control: CGPoint(x: 12, y: 7.6))
        }
        case .shirts: return { p in
            p.move(to: CGPoint(x: 8.6, y: 4.2)); p.addLine(to: CGPoint(x: 4, y: 7.4))
            p.addLine(to: CGPoint(x: 6, y: 10.8)); p.addLine(to: CGPoint(x: 8.2, y: 9.6))
            p.addLine(to: CGPoint(x: 8.2, y: 19.8)); p.addLine(to: CGPoint(x: 15.8, y: 19.8))
            p.addLine(to: CGPoint(x: 15.8, y: 9.6)); p.addLine(to: CGPoint(x: 18, y: 10.8))
            p.addLine(to: CGPoint(x: 20, y: 7.4)); p.addLine(to: CGPoint(x: 15.4, y: 4.2))
            p.closeSubpath()
            p.move(to: CGPoint(x: 8.6, y: 4.2))
            p.addQuadCurve(to: CGPoint(x: 15.4, y: 4.2), control: CGPoint(x: 12, y: 8.4))
        }
        case .trousers: return { p in
            p.move(to: CGPoint(x: 7.4, y: 4)); p.addLine(to: CGPoint(x: 16.6, y: 4))
            p.addLine(to: CGPoint(x: 17.6, y: 20)); p.addLine(to: CGPoint(x: 13.4, y: 20))
            p.addLine(to: CGPoint(x: 12, y: 10.6)); p.addLine(to: CGPoint(x: 10.6, y: 20))
            p.addLine(to: CGPoint(x: 6.4, y: 20))
            p.closeSubpath()
            p.move(to: CGPoint(x: 7.4, y: 7)); p.addLine(to: CGPoint(x: 16.6, y: 7))
        }
        case .shoes: return { p in
            p.move(to: CGPoint(x: 3.2, y: 18.4)); p.addLine(to: CGPoint(x: 3.2, y: 11.4))
            p.addLine(to: CGPoint(x: 7.4, y: 12.6)); p.addLine(to: CGPoint(x: 11, y: 15.6))
            p.addLine(to: CGPoint(x: 17.2, y: 17)); p.addLine(to: CGPoint(x: 20.8, y: 18.1))
            p.addLine(to: CGPoint(x: 20.8, y: 20.4)); p.addLine(to: CGPoint(x: 3.2, y: 20.4))
            p.closeSubpath()
            p.move(to: CGPoint(x: 7.4, y: 12.6)); p.addLine(to: CGPoint(x: 9, y: 10.8))
        }
        case .socks: return { p in
            p.move(to: CGPoint(x: 8.6, y: 3.6)); p.addLine(to: CGPoint(x: 14.2, y: 3.6))
            p.addLine(to: CGPoint(x: 14.2, y: 12.2)); p.addLine(to: CGPoint(x: 17.6, y: 16.1))
            p.addQuadCurve(to: CGPoint(x: 12.9, y: 20.2), control: CGPoint(x: 18.4, y: 20.6))
            p.addLine(to: CGPoint(x: 9.5, y: 17.2))
            p.addQuadCurve(to: CGPoint(x: 8.6, y: 15), control: CGPoint(x: 8.6, y: 16))
            p.closeSubpath()
            p.move(to: CGPoint(x: 8.6, y: 7)); p.addLine(to: CGPoint(x: 14.2, y: 7))
        }
        }
    }

    @MainActor
    func icon(_ color: Color, size: CGFloat = 21) -> some View {
        LineArt(canvas: canvas, color: color, lineWidth: 1.35, draw: drawing)
            .frame(width: size, height: size)
    }
}
