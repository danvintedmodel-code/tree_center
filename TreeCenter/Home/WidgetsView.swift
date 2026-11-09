import SwiftData
import SwiftUI
import TreeCenterData

// Galería de widgets: qué sale en el inicio, con qué cara y de qué tamaño.
//
// Ojo con el nombre: estos son los widgets de dentro de la app. Los de la
// pantalla de bloqueo del iPhone son WidgetKit y son otro trabajo.

struct WidgetsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \HomeWidget.order) private var widgets: [HomeWidget]

    @State private var selected: PersistentIdentifier?

    /// Alto fijo de fila: es lo que hace que el cálculo del destino al arrastrar
    /// sea exacto en vez de una estimación.
    private static let rowHeight: CGFloat = 46

    @State private var dragging: PersistentIdentifier?
    @State private var dragFrom = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            TCScreenHeader(title: "Widgets", back: { dismiss() }) {
                Button("Listo") { dismiss() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(TCColor.moss)
            }

            ScrollView {
                VStack(spacing: 20) {
                    placed
                    if let widget = current {
                        designs(for: widget)
                        sizes(for: widget)
                    }
                    available
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if selected == nil { selected = widgets.first?.persistentModelID } }
    }

    private var current: HomeWidget? {
        widgets.first { $0.persistentModelID == selected } ?? widgets.first
    }

    // MARK: - En tu inicio

    private var placed: some View {
        VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "En tu inicio")

            if widgets.isEmpty {
                Text("El inicio está sin widgets: solo la barra de secciones.")
                    .tcMicro()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tcCard(padding: 16, sunken: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(widgets.enumerated()), id: \.element.persistentModelID) { index, widget in
                        row(widget, at: index)
                            // La fila que se arrastra va por encima de las demás
                            // y con sombra, para que se vea que está en el aire.
                            .offset(y: lift(index))
                            .background(dragging == widget.persistentModelID ? TCColor.card : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: dragging == widget.persistentModelID
                                    ? Color.black.opacity(0.35) : .clear,
                                    radius: 13, y: 6)
                            .zIndex(dragging == widget.persistentModelID ? 1 : 0)

                        if index < widgets.count - 1 && dragging == nil {
                            Divider().overlay(TCColor.line)
                        }
                    }
                }
                .tcCard(padding: 14)
            }
        }
    }

    /// Cuánto se desplaza cada fila mientras se arrastra: la que llevas, con el
    /// dedo; las demás, quietas, porque el hueco ya se ha movido en la lista.
    private func lift(_ index: Int) -> CGFloat {
        guard let dragging,
              let current = widgets.firstIndex(where: { $0.persistentModelID == dragging }),
              current == index else { return 0 }
        return dragOffset - CGFloat(current - dragFrom) * Self.rowHeight
    }

    private func row(_ widget: HomeWidget, at index: Int) -> some View {
        HStack(spacing: 10) {
            grip(for: widget, at: index)

            Button { selected = widget.persistentModelID } label: {
                HStack(spacing: 8) {
                    Text("\(widget.section.label) · \(label(of: widget))")
                        .font(TCFont.font(14, widget.persistentModelID == current?.persistentModelID ? .medium : .regular))
                        .foregroundStyle(widget.persistentModelID == current?.persistentModelID
                                         ? TCColor.text : TCColor.textSoft)
                    Spacer(minLength: 8)
                    Text(widget.size.label)
                        .font(TCFont.font(10))
                        .foregroundStyle(TCColor.textMicro)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(TCColor.line, lineWidth: 1))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { remove(widget) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TCColor.textFaint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quitar")
        }
        .frame(height: Self.rowHeight)
    }

    /// Las rayas de arrastre.
    ///
    /// Dibujadas a mano y con su propio gesto, y no con `List` + `.onMove`, que
    /// sería una línea. El motivo: las asas del sistema solo aparecen con el
    /// `editMode` activo, y en modo edición una fila de `List` se deja de poder
    /// tocar — se quedarían sin funcionar el toque que elige el widget y la X
    /// que lo quita. Además el asa gris del sistema no pega con un dibujo de
    /// líneas de 1,4 px. Por eso tres rectángulos y un `DragGesture`.
    private func grip(for widget: HomeWidget, at index: Int) -> some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(dragging == widget.persistentModelID ? TCColor.moss : TCColor.textFaint)
                    .frame(height: 1.4)
            }
        }
        .frame(width: 16)
        .padding(.horizontal, 7)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityLabel("Cambiar de posición")
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if dragging == nil {
                        dragging = widget.persistentModelID
                        dragFrom = index
                    }
                    dragOffset = value.translation.height
                    reorderWhileDragging()
                }
                .onEnded { _ in
                    // El orden ya se fue aplicando durante el arrastre, así que
                    // aquí solo queda guardarlo y soltar.
                    dragging = nil
                    dragOffset = 0
                    try? context.save()
                }
        )
    }

    /// El destino se calcula siempre desde la posición donde empezó el arrastre,
    /// que no cambia: así el cálculo no se va acumulando error a cada paso.
    private func reorderWhileDragging() {
        guard let dragging,
              let current = widgets.firstIndex(where: { $0.persistentModelID == dragging }) else { return }

        let steps = Int((dragOffset / Self.rowHeight).rounded())
        let target = min(max(dragFrom + steps, 0), widgets.count - 1)
        guard target != current else { return }

        var list = widgets
        let moved = list.remove(at: current)
        list.insert(moved, at: target)
        for (position, widget) in list.enumerated() { widget.order = position }
    }

    private func label(of widget: HomeWidget) -> String {
        WidgetDesign.named(widget.design, in: widget.section).label.lowercased()
    }

    // MARK: - Diseños

    private func designs(for widget: HomeWidget) -> some View {
        let options = WidgetDesign.all(for: widget.section)

        return VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Diseños para \(widget.section.label)",
                           trailing: "\(options.count) disponibles")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                      spacing: 10) {
                ForEach(options) { option in
                    Button {
                        widget.design = option.id
                        if !option.sizes.contains(widget.size) {
                            widget.sizeRaw = (option.sizes.first ?? .wide).rawValue
                        }
                        try? context.save()
                    } label: {
                        VStack(spacing: 9) {
                            option.preview
                                .frame(height: 44)
                            Text(option.label)
                                .font(TCFont.font(10, option.id == widget.design ? .medium : .regular))
                                .foregroundStyle(option.id == widget.design ? TCColor.moss : TCColor.textSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(option.id == widget.design ? TCColor.mossWell : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(option.id == widget.design ? TCColor.moss : TCColor.line,
                                              lineWidth: option.id == widget.design ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tamaño

    private func sizes(for widget: HomeWidget) -> some View {
        let design = WidgetDesign.named(widget.design, in: widget.section)

        return VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Tamaño")

            HStack(spacing: 7) {
                ForEach(WidgetSize.allCases) { size in
                    Button {
                        widget.sizeRaw = size.rawValue
                        try? context.save()
                    } label: {
                        TCChip(text: size.label, selected: size == widget.size)
                            .opacity(design.sizes.contains(size) ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!design.sizes.contains(size))
                }
            }

            if design.sizes.count < WidgetSize.allCases.count {
                Text("El diseño manda sobre el tamaño: «\(design.label.lowercased())» no cabe en todos.")
                    .font(TCFont.font(11))
                    .foregroundStyle(TCColor.textMicro)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Secciones sin widget

    private var available: some View {
        let used = Set(widgets.map(\.section))
        let free = HomeSectionID.allCases.filter { !used.contains($0) }

        return VStack(alignment: .leading, spacing: 10) {
            TCSectionLabel(text: "Sin widget, en la barra")

            if free.isEmpty {
                Text("Todas las secciones tienen widget.").tcMicro()
            } else {
                FlowChips(items: free.map(\.label)) { label in
                    guard let section = free.first(where: { $0.label == label }) else { return }
                    add(section)
                }
                Text("Cualquiera puede subir a widget, y cualquier widget puede bajar a la barra.")
                    .font(TCFont.font(11))
                    .foregroundStyle(TCColor.textMicro)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Acciones

    private func remove(_ widget: HomeWidget) {
        if widget.persistentModelID == selected { selected = nil }
        context.delete(widget)
        try? context.save()
    }

    private func add(_ section: HomeSectionID) {
        let design = WidgetDesign.all(for: section).first
        let widget = HomeWidget(section: section,
                                design: design?.id ?? "number",
                                size: design?.sizes.first ?? .wide,
                                order: widgets.count)
        context.insert(widget)
        try? context.save()
        selected = widget.persistentModelID
    }
}

/// Chips que saltan de línea cuando no caben. SwiftUI no trae un flow layout
/// hasta iOS 16 con `Layout`, y para seis etiquetas esto es más corto.
private struct FlowChips: View {
    let items: [String]
    let tap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 7)],
                  alignment: .leading, spacing: 7) {
            ForEach(items, id: \.self) { item in
                Button { tap(item) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 9, weight: .semibold))
                        Text(item).font(TCFont.font(12))
                    }
                    .foregroundStyle(TCColor.textSoft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(Capsule().stroke(TCColor.lineStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
