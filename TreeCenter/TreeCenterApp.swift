import SwiftUI
import TreeCenterKit

// Este archivo NO forma parte del paquete: va en el target de la app de Xcode.
// Un target de librería no es sitio para un punto de entrada, así que aquí solo
// queda el `@main` y el cierre de la puerta al salir.

@main
struct TreeCenterApp: App {
    @State private var lock = LockController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(lock: lock)
        }
        .onChange(of: scenePhase) { _, phase in
            // Al salir de la app se vuelve a cerrar la puerta.
            // Solo en `.background`: `.inactive` salta también al abrir Face ID
            // o el centro de control, y eso dejaría la app inusable.
            if phase == .background { lock.relock() }
        }
    }
}
