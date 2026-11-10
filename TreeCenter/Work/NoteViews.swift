import SwiftData
import SwiftUI
import TreeCenterCore
import TreeCenterData
import UIKit

// Las notas: cómo se dibujan y cómo se escriben.
//
// Se guardan como texto plano con cuatro marcas (ver NoteMarkup). Aquí se
// dibujan con formato, y las casillas se marcan con el dedo sin abrir el editor.

/// Una casilla del dibujo de la app: cuadrado redondeado, musgo al marcarla.
struct CheckBox: View {
    let on: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(on ? TCColor.moss : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(on ? TCColor.moss : TCColor.lineStrong, lineWidth: 1.4)
            )
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TCColor.onMoss)
                    .opacity(on ? 1 : 0)
            )
            .frame(width: 18, height: 18)
    }
}

/// Una nota dibujada con formato. Si hay `onToggle`, las casillas se marcan al
/// tocarlas; si no, se ven pero no responden (la vista previa del editor).
struct NoteText: View {
    let text: String
    var onToggle: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(NoteMarkup.parse(text).enumerated()), id: \.offset) { index, line in
                switch line {
                case .heading(let title):
                    Text(title)
                        .font(TCFont.font(15, .semibold))
                        .foregroundStyle(TCColor.text)
                        .padding(.top, 4)

                case .check(let done, let label):
                    Button { onToggle?(index) } label: {
                        HStack(spacing: 9) {
                            CheckBox(on: done)
                            Text(label)
                                .font(TCFont.font(13.5))
                                .foregroundStyle(done ? TCColor.textMicro : TCColor.text)
                                .strikethrough(done, color: TCColor.textMicro)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onToggle == nil)

                case .bullet(let label):
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text("•").foregroundStyle(TCColor.moss)
                        Text(label)
                            .font(TCFont.font(13.5))
                            .foregroundStyle(TCColor.text)
                    }

                case .text(let paragraph):
                    Text(paragraph)
                        .font(TCFont.font(13.5))
                        .foregroundStyle(TCColor.text)
                        .lineSpacing(2)

                case .blank:
                    Spacer().frame(height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - El editor

/// Por qué un `UITextView` y no el `TextEditor` de SwiftUI: los botones de la
/// barra ponen la marca en la línea donde está el cursor, y en iOS 17 el
/// `TextEditor` no deja saber dónde está el cursor. Eso llegó en iOS 18.
struct MarkupTextView: UIViewRepresentable {
    @Binding var text: String
    let controller: MarkupController

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = UIFont(name: "InstrumentSans-Regular", size: 15) ?? .systemFont(ofSize: 15)
        view.textColor = UIColor(TCColor.text)
        view.tintColor = UIColor(TCColor.moss)
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        view.text = text
        controller.textView = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}

/// Lo que hacen los botones de la barra sobre el texto. Guarda el `UITextView`
/// para saber dónde está el cursor.
final class MarkupController {
    weak var textView: UITextView?

    /// - Parameter atLineStart: las marcas (título, lista, casilla) van al
    ///   principio de la línea; la hora va justo donde está el cursor.
    func insert(_ mark: String, atLineStart: Bool) {
        guard let view = textView else { return }
        let current = view.text ?? ""

        // El cursor de UIKit cuenta en UTF-16 y el de Swift en caracteres: se
        // traduce para que un acento o un emoji no descuadren la inserción.
        let utf16 = min(view.selectedRange.location, current.utf16.count)
        let index = String.Index(utf16Offset: utf16, in: current)
        let cursor = current.distance(from: current.startIndex, to: index)

        let result: (text: String, cursor: Int)
        if atLineStart {
            result = NoteMarkup.insertMark(mark, in: current, at: cursor)
        } else {
            let chars = Array(current)
            let at = min(cursor, chars.count)
            result = (String(chars[..<at]) + mark + String(chars[at...]), at + mark.count)
        }

        view.text = result.text
        let newIndex = result.text.index(result.text.startIndex, offsetBy: result.cursor)
        view.selectedRange = NSRange(location: newIndex.utf16Offset(in: result.text), length: 0)
        view.delegate?.textViewDidChange?(view)
        view.becomeFirstResponder()
    }
}

struct NoteEditor<Owner: WorkspaceOwner>: View {
    let owner: Owner
    /// Nil para una nota nueva.
    let note: WorkNote?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var loaded = false
    @State private var controller = MarkupController()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancelar") { dismiss() }
                    .font(TCFont.font(14)).foregroundStyle(TCColor.textSoft)
                Spacer()
                Text(note == nil ? "Nota de hoy" : day(note?.createdAt ?? .now))
                    .font(TCFont.font(14, .semibold)).foregroundStyle(TCColor.text)
                Spacer()
                Button("Guardar") { save() }
                    .font(TCFont.font(14, .semibold))
                    .foregroundStyle(TCColor.moss)
            }
            .padding(.horizontal, TCSpace.gutter)
            .padding(.vertical, 16)
            .background(TCColor.cardSunken)

            toolbar
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 10)

            MarkupTextView(text: $text, controller: controller)
                .frame(minHeight: 190)
                .background(TCColor.card)
                .clipShape(RoundedRectangle(cornerRadius: TCRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TCRadius.control, style: .continuous)
                        .stroke(TCColor.line, lineWidth: 1)
                )
                .padding(.horizontal, TCSpace.gutter)

            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    TCSectionLabel(text: "Así queda")
                    NoteText(text: text)
                        .tcCard(padding: 14)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .background(TCColor.bg)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = note?.text ?? ""
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            tool("Título") { controller.insert("# ", atLineStart: true) }
            tool("Lista") { controller.insert("• ", atLineStart: true) }
            tool("Casilla") { controller.insert("[ ] ", atLineStart: true) }
            tool("Hora") {
                let f = DateFormatter()
                f.dateFormat = "H:mm"
                controller.insert(f.string(from: .now) + " · ", atLineStart: false)
            }
        }
    }

    private func tool(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TCChip(text: title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d 'de' MMMM"
        return f.string(from: date)
    }

    private func save() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let note {
            note.text = text
            note.editedAt = .now
        } else if !clean.isEmpty {
            let new = WorkNote(text: text)
            context.insert(new)
            owner.adopt(new)
        }

        try? context.save()
        dismiss()
    }
}
