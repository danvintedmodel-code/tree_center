import SwiftUI

// El lienzo donde dibujas el trazo.
//
// Lo importante es lo que NO hace: no pinta nada. Ni línea, ni puntos, ni rastro.
// Quien mire la pantalla por encima de tu hombro no ve el trazo, solo tu dedo.
// Las cuatro esquinas en musgo están para decirte dónde está el área, nada más.

struct StrokeCanvas: View {
    /// Trazos crudos en coordenadas del lienzo. Cada arrastre añade uno.
    @Binding var strokes: [[CGPoint]]

    /// Se llama cuando pasa un rato sin dibujar: ahí se da el trazo por terminado.
    var onFinished: () -> Void

    /// Cuánto se espera tras levantar el dedo antes de dar el trazo por terminado.
    /// Tiene que dar margen a levantar el dedo entre dos palos de una X.
    var idleDelay: Duration = .milliseconds(900)

    var isEnabled: Bool = true

    @State private var current: [CGPoint] = []
    @State private var idleTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(TCColor.cardSunken)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(TCColor.lineStrong, lineWidth: 1)
                )

            CornerBrackets()
                .padding(20)
        }
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .gesture(drawGesture)
        .allowsHitTesting(isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel("Lienzo del trazo de acceso")
        .accessibilityHint("Dibuja con el dedo. El trazo no se muestra en pantalla.")
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                idleTask?.cancel()
                current.append(value.location)
            }
            .onEnded { _ in
                if current.count >= 2 { strokes.append(current) }
                current = []
                scheduleFinish()
            }
    }

    private func scheduleFinish() {
        idleTask?.cancel()
        idleTask = Task {
            try? await Task.sleep(for: idleDelay)
            guard !Task.isCancelled, !strokes.isEmpty else { return }
            await MainActor.run { onFinished() }
        }
    }
}

/// Las cuatro escuadras que marcan el área sin dibujar un marco entero.
private struct CornerBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let arm: CGFloat = 18
            let w = geo.size.width, h = geo.size.height

            Path { p in
                p.move(to: CGPoint(x: 0, y: arm)); p.addLine(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: arm, y: 0))
                p.move(to: CGPoint(x: w - arm, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: arm))
                p.move(to: CGPoint(x: w, y: h - arm)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - arm, y: h))
                p.move(to: CGPoint(x: arm, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - arm))
            }
            .stroke(TCColor.moss, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}
