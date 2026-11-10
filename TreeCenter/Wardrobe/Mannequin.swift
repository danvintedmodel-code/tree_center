import SwiftUI
import TreeCenterData
import UIKit

// El maniquí plano: una figura recortada, de frente, con la ropa puesta encima
// por capas, como un recortable.
//
// Se descartó el 3D realista: para que una prenda caiga como de verdad hace falta
// un modelo 3D de cada una, y eso no sale de una foto. Esto sí: cada prenda va en
// su sitio del cuerpo y en el orden de vestirse (los calcetines debajo de las
// zapatillas, la camiseta debajo de la sudadera).
//
// Si la prenda tiene foto, se pone la foto recortada, que el propio iPhone quita
// del fondo al hacerla; si no, la silueta de la prenda en su color.

struct Mannequin: View {
    let worn: [Garment]

    private let canvas = CGSize(width: 160, height: 316)

    /// El orden de vestirse: lo que va debajo, primero.
    static let layers: [GarmentCategory] = [.socks, .trousers, .shoes, .shirts, .hoodies, .necklaces, .caps]

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / canvas.width, geo.size.height / canvas.height)
            let dx = (geo.size.width - canvas.width * scale) / 2
            let dy = (geo.size.height - canvas.height * scale) / 2
            let t = CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: dx, y: dy))

            ZStack(alignment: .topLeading) {
                silhouette.applying(t).fill(TCColor.track)
                silhouette.applying(t).stroke(TCColor.lineStrong, lineWidth: 1)

                ForEach(Self.layers, id: \.self) { category in
                    if let garment = wornBy[category] {
                        piece(garment, category: category, transform: t, scale: scale, dx: dx, dy: dy)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var wornBy: [GarmentCategory: Garment] {
        var map: [GarmentCategory: Garment] = [:]
        for garment in worn { map[garment.category] = garment }
        return map
    }

    private var label: String {
        worn.isEmpty
            ? "Maniquí sin ropa"
            : "Maniquí con " + worn.map(\.name).joined(separator: ", ")
    }

    @ViewBuilder
    private func piece(_ garment: Garment, category: GarmentCategory,
                       transform t: CGAffineTransform, scale: CGFloat, dx: CGFloat, dy: CGFloat) -> some View {
        let shape = Self.shape(category)

        if let data = garment.image, let image = UIImage(data: data) {
            // La foto ocupa la caja de su sitio en el cuerpo, sin deformarse.
            let box = shape.boundingRect
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: box.width * scale, height: box.height * scale)
                .offset(x: dx + box.minX * scale, y: dy + box.minY * scale)
        } else if category == .necklaces {
            shape.applying(t).stroke(garment.color.swiftUI, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        } else {
            shape.applying(t).fill(garment.color.swiftUI)
            shape.applying(t).stroke(Color.black.opacity(0.3), lineWidth: 1)
        }
    }

    // MARK: - El cuerpo

    private var silhouette: Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: 60, y: 20, width: 40, height: 40))
        p.addRoundedRect(in: CGRect(x: 73, y: 56, width: 14, height: 22), cornerSize: CGSize(width: 4, height: 4))

        // Torso
        p.move(to: CGPoint(x: 52, y: 80))
        p.addQuadCurve(to: CGPoint(x: 108, y: 80), control: CGPoint(x: 80, y: 72))
        p.addLine(to: CGPoint(x: 114, y: 150))
        p.addQuadCurve(to: CGPoint(x: 98, y: 170), control: CGPoint(x: 112, y: 168))
        p.addLine(to: CGPoint(x: 62, y: 170))
        p.addQuadCurve(to: CGPoint(x: 46, y: 150), control: CGPoint(x: 48, y: 168))
        p.closeSubpath()

        // Brazos
        for side in [CGFloat(1), -1] {
            let x = { (value: CGFloat) in 80 + (value - 80) * side }
            p.move(to: CGPoint(x: x(52), y: 82))
            p.addLine(to: CGPoint(x: x(38), y: 128))
            p.addLine(to: CGPoint(x: x(34), y: 170))
            p.addLine(to: CGPoint(x: x(42), y: 171))
            p.addLine(to: CGPoint(x: x(48), y: 132))
            p.addLine(to: CGPoint(x: x(58), y: 100))
            p.closeSubpath()
        }
        p.addEllipse(in: CGRect(x: 32, y: 170, width: 12, height: 12))
        p.addEllipse(in: CGRect(x: 116, y: 170, width: 12, height: 12))

        // Piernas y pies
        p.addRect(CGRect(x: 63, y: 166, width: 15, height: 126))
        p.addRect(CGRect(x: 82, y: 166, width: 15, height: 126))
        p.addRoundedRect(in: CGRect(x: 56, y: 290, width: 24, height: 12), cornerSize: CGSize(width: 3, height: 3))
        p.addRoundedRect(in: CGRect(x: 80, y: 290, width: 24, height: 12), cornerSize: CGSize(width: 3, height: 3))
        return p
    }

    // MARK: - La ropa

    static func shape(_ category: GarmentCategory) -> Path {
        var p = Path()
        switch category {
        case .socks:
            p.addRect(CGRect(x: 62, y: 268, width: 16, height: 24))
            p.addRect(CGRect(x: 82, y: 268, width: 16, height: 24))

        case .trousers:
            p.move(to: CGPoint(x: 58, y: 160))
            p.addLine(to: CGPoint(x: 102, y: 160))
            p.addLine(to: CGPoint(x: 101, y: 292))
            p.addLine(to: CGPoint(x: 85, y: 292))
            p.addLine(to: CGPoint(x: 80, y: 198))
            p.addLine(to: CGPoint(x: 75, y: 292))
            p.addLine(to: CGPoint(x: 59, y: 292))
            p.closeSubpath()

        case .shoes:
            p.move(to: CGPoint(x: 55, y: 287)); p.addLine(to: CGPoint(x: 80, y: 287))
            p.addLine(to: CGPoint(x: 82, y: 304)); p.addLine(to: CGPoint(x: 50, y: 304))
            p.addQuadCurve(to: CGPoint(x: 55, y: 287), control: CGPoint(x: 50, y: 292))
            p.move(to: CGPoint(x: 80, y: 287)); p.addLine(to: CGPoint(x: 105, y: 287))
            p.addQuadCurve(to: CGPoint(x: 110, y: 304), control: CGPoint(x: 110, y: 292))
            p.addLine(to: CGPoint(x: 78, y: 304))
            p.closeSubpath()

        case .shirts:
            p.move(to: CGPoint(x: 50, y: 80))
            p.addQuadCurve(to: CGPoint(x: 110, y: 80), control: CGPoint(x: 80, y: 71))
            p.addLine(to: CGPoint(x: 126, y: 104)); p.addLine(to: CGPoint(x: 113, y: 112))
            p.addLine(to: CGPoint(x: 108, y: 99)); p.addLine(to: CGPoint(x: 110, y: 162))
            p.addLine(to: CGPoint(x: 50, y: 162)); p.addLine(to: CGPoint(x: 52, y: 99))
            p.addLine(to: CGPoint(x: 47, y: 112)); p.addLine(to: CGPoint(x: 34, y: 104))
            p.closeSubpath()

        case .hoodies:
            p.move(to: CGPoint(x: 49, y: 78))
            p.addQuadCurve(to: CGPoint(x: 111, y: 78), control: CGPoint(x: 80, y: 64))
            p.addLine(to: CGPoint(x: 127, y: 126)); p.addLine(to: CGPoint(x: 128, y: 170))
            p.addLine(to: CGPoint(x: 116, y: 170)); p.addLine(to: CGPoint(x: 112, y: 132))
            p.addLine(to: CGPoint(x: 109, y: 106)); p.addLine(to: CGPoint(x: 111, y: 172))
            p.addLine(to: CGPoint(x: 49, y: 172)); p.addLine(to: CGPoint(x: 51, y: 106))
            p.addLine(to: CGPoint(x: 48, y: 132)); p.addLine(to: CGPoint(x: 44, y: 170))
            p.addLine(to: CGPoint(x: 32, y: 170)); p.addLine(to: CGPoint(x: 33, y: 126))
            p.closeSubpath()

        case .necklaces:
            p.move(to: CGPoint(x: 71, y: 72))
            p.addQuadCurve(to: CGPoint(x: 89, y: 72), control: CGPoint(x: 80, y: 95))
            p.addEllipse(in: CGRect(x: 77, y: 86, width: 6, height: 6))

        case .caps:
            p.move(to: CGPoint(x: 59, y: 34))
            p.addQuadCurve(to: CGPoint(x: 101, y: 34), control: CGPoint(x: 80, y: 6))
            p.closeSubpath()
            p.move(to: CGPoint(x: 96, y: 31)); p.addLine(to: CGPoint(x: 119, y: 34))
            p.addQuadCurve(to: CGPoint(x: 116, y: 39), control: CGPoint(x: 121, y: 39))
            p.addLine(to: CGPoint(x: 96, y: 37))
            p.closeSubpath()
        }
        return p
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
