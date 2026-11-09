import SwiftData
import SwiftUI
import TreeCenterData

/// La raíz de la app: o la puerta, o el centro del árbol. Nunca las dos.
public struct RootView: View {
    @Bindable var lock: LockController

    private let container: ModelContainer
    private let storeIsTemporary: Bool
    private let restored: Bool
    private let cloudFailed: Bool

    @State private var dismissedRestoreNote = false

    public init(lock: LockController) {
        self.lock = lock

        // Lo primero de todo, antes de que exista el contenedor: si hay una
        // copia esperando, entra ahora. Con el almacén abierto, sustituir los
        // archivos no da un error, da una base a medias.
        restored = StoreFiles.applyPendingRestore()

        // Luego, en este orden: iCloud si lo has pedido, el iPhone si no (o si
        // iCloud no puede), y memoria como último recurso.
        //
        // Que iCloud falle es lo normal hasta que el entitlement esté puesto en
        // Xcode, así que caer al almacén local tiene que ser silencioso para la
        // app y visible para ti: de ahí el aviso de arriba.
        if TreeCenterSettings.usesCloud {
            if let cloud = try? TreeCenterSchema.container(cloud: true) {
                container = cloud
                storeIsTemporary = false
                cloudFailed = false
            } else if let disk = try? TreeCenterSchema.container() {
                container = disk
                storeIsTemporary = false
                cloudFailed = true
            } else if let memory = try? TreeCenterSchema.container(inMemory: true) {
                container = memory
                storeIsTemporary = true
                cloudFailed = true
            } else {
                fatalError("No se ha podido abrir ningún almacén de Tree Center.")
            }
        } else if let disk = try? TreeCenterSchema.container() {
            container = disk
            storeIsTemporary = false
            cloudFailed = false
        } else if let memory = try? TreeCenterSchema.container(inMemory: true) {
            // Perder una sesión de datos es malo; una app que no abre es peor,
            // y así queda margen para exportar lo que haya y arreglarlo.
            container = memory
            storeIsTemporary = true
            cloudFailed = false
        } else {
            fatalError("No se ha podido abrir ningún almacén de Tree Center.")
        }
    }

    public var body: some View {
        ZStack {
            TCColor.bg.ignoresSafeArea()

            if lock.phase == .unlocked {
                VStack(spacing: 0) {
                    if storeIsTemporary { banner(.clay, "Los datos de esta sesión no se están guardando.") }
                    if cloudFailed { banner(.sand, "iCloud no ha podido abrirse. Se está guardando solo en este iPhone.") }
                    if restored && !dismissedRestoreNote {
                        restoredBanner
                    }
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

    private enum BannerTint { case clay, sand, moss }

    private func banner(_ tint: BannerTint, _ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: tint == .moss ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.system(size: 13, weight: .light))
            Text(text)
                .font(TCFont.font(12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color(tint))
        .padding(.horizontal, TCSpace.gutter)
        .padding(.vertical, 10)
        .background(TCColor.cardSunken)
    }

    private func color(_ tint: BannerTint) -> Color {
        switch tint {
        case .clay: return TCColor.clay
        case .sand: return TCColor.sand
        case .moss: return TCColor.moss
        }
    }

    /// El de la restauración sí se puede cerrar: los otros dos describen algo
    /// que sigue pasando, y este una cosa que ya pasó.
    private var restoredBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13, weight: .light))
            Text("Copia restaurada.")
                .font(TCFont.font(12))
            Spacer(minLength: 0)
            Button { dismissedRestoreNote = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(TCColor.moss)
        .padding(.horizontal, TCSpace.gutter)
        .padding(.vertical, 10)
        .background(TCColor.mossWell)
    }
}
