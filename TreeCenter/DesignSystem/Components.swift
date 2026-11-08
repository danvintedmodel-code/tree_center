import SwiftUI

// Las piezas que se repiten en las 21 pantallas.
// Todo sale de Theme.swift: aquí no hay ni un color escrito a mano.

// MARK: - Tarjeta

struct TCCardStyle: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = TCRadius.cardLarge
    var sunken: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(sunken ? TCColor.cardSunken : TCColor.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(TCColor.line, lineWidth: 1)
            )
    }
}

extension View {
    func tcCard(padding: CGFloat = 16,
                radius: CGFloat = TCRadius.cardLarge,
                sunken: Bool = false) -> some View {
        modifier(TCCardStyle(padding: padding, radius: radius, sunken: sunken))
    }
}

// MARK: - Botones

struct TCPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TCFont.font(15, .semibold))
            .foregroundStyle(TCColor.onMoss)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(TCColor.moss)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TCGhostButtonStyle: ButtonStyle {
    var dashed: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TCFont.font(15, .medium))
            .foregroundStyle(TCColor.text)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        TCColor.lineStrong,
                        style: StrokeStyle(lineWidth: 1, dash: dashed ? [5, 4] : [])
                    )
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Chip

struct TCChip: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(TCFont.font(12, selected ? .medium : .regular))
            .foregroundStyle(selected ? TCColor.onMoss : TCColor.textSoft)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(selected ? TCColor.moss : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(selected ? Color.clear : TCColor.lineStrong, lineWidth: 1)
            )
    }
}

// MARK: - Barra de avance

struct TCProgressBar: View {
    /// De 0 a 1. Se recorta sola: un valor fuera de rango no rompe el dibujo.
    let value: Double
    var tint: Color = TCColor.moss
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(TCColor.track)
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Anillo

struct TCRing: View {
    let value: Double
    var tint: Color = TCColor.moss
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle().stroke(TCColor.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Etiqueta de sección

struct TCSectionLabel: View {
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(text.uppercased()).tcLabel()
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing).tcMicro()
            }
        }
    }
}

// MARK: - La marca

struct TreeMark: View {
    var size: CGFloat = 42
    var tint: Color = TCColor.moss

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 34
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            var trunk = Path()
            trunk.move(to: p(17, 31)); trunk.addLine(to: p(17, 13))
            trunk.move(to: p(17, 20)); trunk.addLine(to: p(10, 15))
            trunk.move(to: p(17, 24)); trunk.addLine(to: p(24, 19))
            context.stroke(trunk, with: .color(tint),
                           style: StrokeStyle(lineWidth: 1.35 * s, lineCap: .round))

            for (cx, cy, r) in [(17.0, 9.0, 4.2), (8.5, 13.5, 2.6), (25.5, 17.5, 2.6)] {
                let rect = CGRect(x: (cx - r) * s, y: (cy - r) * s, width: r * 2 * s, height: r * 2 * s)
                context.stroke(Path(ellipseIn: rect), with: .color(tint), lineWidth: 1.35 * s)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Tree Center")
    }
}
