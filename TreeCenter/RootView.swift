import SwiftData
import SwiftUI
import TreeCenterData

/// La raíz de la app: o la puerta, o el centro del árbol. Nunca las dos.
public struct RootView: View {
    @Bindable var lock: LockController

    private let container: ModelContainer
    private let storeIsTemporary: Bool
    private let restored: Bool

    @State private var dismissedRestoreNote = false

    public init(lock: LockController) {
        self.lock = lock

        // Lo primero de todo, antes de que exista el contenedor: si hay una
        // copia esperando, entra ahora. Con el almacén abierto, sustituir los
        // archivos no da un error, da una base a medias.
        restored = StoreFiles.applyPendingRestore()

        // Sin iCloud: instalada gratis, Apple no da el permiso de CloudKit, así
        // que el almacén vive solo en el iPhone. Si el de disco no abre, se
        // arranca en memoria: perder una sesión de datos es malo, pero una app
        // que no abre es peor, y así queda margen para exportar lo que haya.
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
                    if storeIsTemporary { banner(.clay, "Los datos de esta sesión no se están guardando.") }
                    if let left = InstallInfo.daysLeft(), left <= 1 {
                        banner(.sand, "\(InstallInfo.describe()). Renuévala desde el PC con el iPhone conectado.")
                    }
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

            // Cada renovación de la firma trae una fecha de caducidad nueva, así
            // que el aviso del día antes se reprograma en cada arranque.
            let defaults = UserDefaults.standard
            let warnExpiry = defaults.object(forKey: InstallInfo.expiryWarnKey) as? Bool ?? true
            let warnBackup = defaults.object(forKey: InstallInfo.backupWarnKey) as? Bool ?? true
            // El aviso de caducidad viene encendido de serie, y sin permiso no
            // sonaría: instalada con firma de 7 días, se pide en el arranque.
            if InstallInfo.signature != nil && warnExpiry {
                _ = await ReminderScheduler.ensurePermission()
            }
            InstallInfo.scheduleExpiryWarning(enabled: warnExpiry)
            InstallInfo.scheduleBackupReminder(enabled: warnBackup)
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
