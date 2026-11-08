import SwiftUI

struct LockView: View {
    @Bindable var lock: LockController

    @State private var strokes: [[CGPoint]] = []
    @State private var shake = 0
    @State private var now = Date.now

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 70)

            TreeMark(size: 42)

            Text("TREECENTER")
                .font(TCFont.font(13, .semibold))
                .tracking(4.4)
                .padding(.leading, 4.4)
                .foregroundStyle(TCColor.text)
                .padding(.top, 18)

            Text(headline)
                .font(TCFont.font(14))
                .foregroundStyle(TCColor.textSoft)
                .padding(.top, 11)

            StrokeCanvas(strokes: $strokes,
                         onFinished: finish,
                         isEnabled: lock.canDraw)
                .frame(width: 280, height: 280)
                .padding(.top, 30)
                .offset(x: shakeOffset)
                .animation(.spring(response: 0.25, dampingFraction: 0.35), value: shake)

            Text(footnote)
                .font(TCFont.font(12))
                .multilineTextAlignment(.center)
                .foregroundStyle(lock.isError ? TCColor.clay : TCColor.textMicro)
                .frame(height: 34)
                .padding(.top, 14)
                .padding(.horizontal, 24)
                .animation(.easeOut(duration: 0.2), value: footnote)

            Spacer(minLength: 16)

            if lock.phase == .locked, BiometricAuth.available != .none, LockController.biometricsEnabled {
                Button {
                    Task { await lock.tryBiometrics() }
                } label: {
                    HStack(spacing: 10) {
                        FaceIDGlyph()
                        Text(BiometricAuth.label)
                    }
                }
                .buttonStyle(TCGhostButtonStyle())
                .disabled(lock.isWaitingOutPenalty)
                .opacity(lock.isWaitingOutPenalty ? 0.4 : 1)
            }

            Text("Sin red. Todo vive en el iPhone.")
                .font(TCFont.font(11))
                .foregroundStyle(TCColor.textFaint)
                .padding(.top, 16)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TCColor.bg)
        .onReceive(tick) { now = $0 }
        .task {
            // Face ID se ofrece solo al abrir, que es lo que espera cualquiera.
            if lock.phase == .locked { await lock.tryBiometrics() }
        }
    }

    // MARK: - Texto según el momento

    private var headline: String {
        switch lock.phase {
        case .enrollFirst: return "Dibuja tu trazo nuevo"
        case .enrollConfirm: return "Repítelo para confirmarlo"
        case .locked: return "Dibuja tu trazo"
        case .unlocked: return ""
        }
    }

    private var footnote: String {
        if lock.isWaitingOutPenalty {
            _ = now   // fuerza el redibujado cada segundo
            return "Espera \(lock.secondsLeft) s antes de volver a intentarlo."
        }
        if let message = lock.message { return message }
        switch lock.phase {
        case .enrollFirst, .enrollConfirm:
            return "El trazo no se dibuja en pantalla.\nTe lo tienes que acordar tú."
        default:
            return "El trazo no se dibuja en pantalla.\n3 intentos, luego 30 s de espera."
        }
    }

    private var shakeOffset: CGFloat {
        shake == 0 ? 0 : (shake % 2 == 0 ? 9 : -9)
    }

    private func finish() {
        let drawn = strokes
        strokes = []
        lock.handle(drawn)

        guard lock.isError else { return }
        // Dos sacudidas cortas y vuelta al sitio.
        shake += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { shake += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { shake = 0 }
    }
}

/// El icono de Face ID, dibujado con el mismo trazo que el resto de la app.
private struct FaceIDGlyph: View {
    var body: some View {
        Canvas { context, size in
            let s = size.width / 20
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            var path = Path()
            path.move(to: p(2, 7)); path.addLine(to: p(2, 4.5))
            path.addQuadCurve(to: p(4.5, 2), control: p(2, 2))
            path.addLine(to: p(7, 2))

            path.move(to: p(13, 2)); path.addLine(to: p(15.5, 2))
            path.addQuadCurve(to: p(18, 4.5), control: p(18, 2))
            path.addLine(to: p(18, 7))

            path.move(to: p(18, 13)); path.addLine(to: p(18, 15.5))
            path.addQuadCurve(to: p(15.5, 18), control: p(18, 18))
            path.addLine(to: p(13, 18))

            path.move(to: p(7, 18)); path.addLine(to: p(4.5, 18))
            path.addQuadCurve(to: p(2, 15.5), control: p(2, 18))
            path.addLine(to: p(2, 13))

            path.move(to: p(7.5, 8)); path.addLine(to: p(7.5, 9.6))
            path.move(to: p(12.5, 8)); path.addLine(to: p(12.5, 9.6))

            path.move(to: p(7.4, 12.8))
            path.addQuadCurve(to: p(12.6, 12.8), control: p(10, 14.8))

            context.stroke(path, with: .color(TCColor.text),
                           style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
        }
        .frame(width: 19, height: 19)
    }
}
