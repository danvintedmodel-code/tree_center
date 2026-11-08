import SwiftUI

/// La raíz de la app: o la puerta, o el centro del árbol. Nunca las dos.
public struct RootView: View {
    @Bindable var lock: LockController

    public init(lock: LockController) {
        self.lock = lock
    }

    public var body: some View {
        ZStack {
            TCColor.bg.ignoresSafeArea()

            if lock.phase == .unlocked {
                HomeView()
                    .transition(.opacity)
            } else {
                LockView(lock: lock)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: lock.phase)
    }
}
