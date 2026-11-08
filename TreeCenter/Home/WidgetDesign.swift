import SwiftUI
import TreeCenterData

// El catálogo de caras de widget. `HomeWidget.design` guarda solo el id en
// texto, así que esta es la tabla que dice qué ids existen, cómo se llaman en
// castellano y en qué tamaños caben.
//
// Si un id guardado ya no está en la tabla (porque se renombró), `named` cae en
// el primero de la sección en vez de dejar la pantalla a medias.

struct WidgetDesign: Identifiable, Equatable {
    let id: String
    let label: String
    let sizes: [WidgetSize]
    let glyph: Glyph

    enum Glyph { case ring, week, number, meter, split, rings, date, list }

    var preview: some View { WidgetGlyph(glyph: glyph) }

    static func all(for section: HomeSectionID) -> [WidgetDesign] {
        switch section {
        case .gym:
            return [
                .init(id: "ring", label: "Aro", sizes: [.large, .wide], glyph: .ring),
                .init(id: "week", label: "Semana", sizes: [.wide, .large], glyph: .week),
                .init(id: "number", label: "Cifra", sizes: [.small, .wide], glyph: .number)
            ]
        case .food:
            return [
                .init(id: "macros", label: "Barra", sizes: [.small, .wide, .large], glyph: .meter),
                .init(id: "ring", label: "Aro", sizes: [.small, .wide, .large], glyph: .ring),
                .init(id: "number", label: "Cifra", sizes: [.small, .wide], glyph: .number)
            ]
        case .calendar:
            return [
                .init(id: "next", label: "Próxima", sizes: [.small, .wide, .large], glyph: .date),
                .init(id: "list", label: "Lista", sizes: [.wide, .large], glyph: .list),
                .init(id: "number", label: "Cuenta atrás", sizes: [.small, .wide], glyph: .number)
            ]
        case .finance:
            return [
                .init(id: "rings", label: "Aros", sizes: [.large, .wide], glyph: .rings),
                .init(id: "split", label: "Reparto", sizes: [.wide, .large], glyph: .split),
                .init(id: "number", label: "Saldo", sizes: [.small, .wide], glyph: .number)
            ]
        default:
            return [
                .init(id: "number", label: "Cifra", sizes: [.small, .wide], glyph: .number),
                .init(id: "list", label: "Lista", sizes: [.wide, .large], glyph: .list)
            ]
        }
    }

    static func named(_ id: String, in section: HomeSectionID) -> WidgetDesign {
        let catalogue = all(for: section)
        return catalogue.first { $0.id == id } ?? catalogue[0]
    }
}

/// El dibujito del selector. No es el widget: es su silueta, lo justo para
/// reconocer de un vistazo cuál es cuál.
struct WidgetGlyph: View {
    let glyph: WidgetDesign.Glyph

    var body: some View {
        switch glyph {
        case .ring:
            ZStack {
                Circle().stroke(TCColor.track, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(TCColor.moss, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 30, height: 30)

        case .week:
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(index < 4 ? TCColor.moss : TCColor.track)
                        .frame(width: 3, height: index < 4 ? 26 : 12)
                }
            }

        case .number:
            Text("24")
                .font(TCFont.font(24, .semibold))
                .monospacedDigit()
                .foregroundStyle(TCColor.neutralData)

        case .meter:
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(TCColor.track).frame(width: 36, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(TCColor.moss).frame(width: 22, height: 4)
                    }
                Capsule().fill(TCColor.track).frame(width: 36, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(TCColor.moss).frame(width: 13, height: 4)
                    }
                Capsule().fill(TCColor.track).frame(width: 36, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(TCColor.moss).frame(width: 30, height: 4)
                    }
            }

        case .split:
            HStack(spacing: 2) {
                Rectangle().fill(TCColor.moss).frame(width: 16)
                Rectangle().fill(TCColor.blue).frame(width: 9)
                Rectangle().fill(TCColor.sand).frame(width: 5)
            }
            .frame(height: 22)
            .clipShape(Capsule())

        case .rings:
            ZStack {
                Circle().stroke(TCColor.moss, lineWidth: 3).frame(width: 32, height: 32)
                Circle().stroke(TCColor.blue, lineWidth: 3).frame(width: 22, height: 22)
                Circle().stroke(TCColor.sand, lineWidth: 3).frame(width: 12, height: 12)
            }

        case .date:
            VStack(spacing: 2) {
                Text("14").font(TCFont.font(19, .semibold)).foregroundStyle(TCColor.neutralData)
                Text("NOV").font(TCFont.font(8, .semibold)).tracking(1.4)
                    .foregroundStyle(TCColor.textMicro)
            }

        case .list:
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 5) {
                        Circle().fill(TCColor.moss.opacity(index == 0 ? 1 : 0.35))
                            .frame(width: 4, height: 4)
                        Capsule().fill(TCColor.track)
                            .frame(width: index == 0 ? 32 : 24, height: 3)
                    }
                }
            }
        }
    }
}
