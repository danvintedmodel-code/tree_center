import SwiftData
import SwiftUI
import TreeCenterData

/// La raíz de la app: o la puerta, o el centro del árbol. Nunca las dos.
public struct RootView: View {
    @Bindable var lock: LockController

    private let container: ModelContainer
    private let storeIsTemporary: Bool

    public init(lock: LockController) {
        self.lock = lock

        // Si el almacén de disco no abre, se arranca en memoria en vez de cerrarse.
        // Perder una sesión de datos es malo; una app que no abre es peor, y así
        // queda margen para exportar lo que haya y arreglarlo.
        if let disk = try? TreeCenterSchema.container() {
            container = disk
            storeIsTemporary = false
        } else if let memory = try? TreeCenterSchema.container(inMemory: true) {
            container = memory
            storeIsTemporary = true
        } else {
            fatalError("No se ha podido abrir ningún almacén de Tree Center.")
        }
    }

    public var body: some View {
        ZStack {
            TCColor.bg.ignoresSafeArea()

            if lock.phase == .unlocked {
                VStack(spacing: 0) {
                    if storeIsTemporary { temporaryStoreBanner }
                    HomeView(lock: lock)
                }
                .transition(.opacity)
            } else {
                LockView(lock: lock)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: lock.phase)
        .modelContainer(container)
        .task {
            // El armazón mínimo: la semana, las carteras y los widgets.
            try? TreeCenterSchema.seedIfEmpty(container.mainContext)
        }
    }

    private var temporaryStoreBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .light))
            Text("Los datos de esta sesión no se están guardando.")
                .font(TCFont.font(12))
            Spacer(minLength: 0)
        }
        .foregroundStyle(TCColor.clay)
        .padding(.horizontal, TCSpace.gutter)
        .padding(.vertical, 10)
        .background(TCColor.cardSunken)
    }
}
