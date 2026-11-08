import SwiftUI

// El centro del árbol: widgets arriba, barra de secciones abajo y los cuatro botones
// pegados al borde.
//
// Los iconos son SF Symbols de momento. El set propio de línea de 1,4 px entra
// cuando estén dibujados; cambiar uno por otro es tocar solo `Section.symbol`.

struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    gymWidget
                    HStack(spacing: 12) {
                        mediumWidget(label: "COMIDA", value: "1 840",
                                     caption: "de 2 700 kcal", progress: 0.68)
                        calendarWidget
                    }
                    Button("Añadir widget") {}
                        .buttonStyle(TCGhostButtonStyle(dashed: true))
                        .frame(height: 44)
                }
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            sectionsBar
                .padding(.horizontal, TCSpace.gutter)
                .padding(.bottom, 14)

            tabBar
                .padding(.horizontal, TCSpace.gutter)
        }
        .background(TCColor.bg)
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tree Center").tcTitle()
                Text(todayLine).tcBody()
            }
            Spacer()
            Circle()
                .fill(TCColor.card)
                .overlay(Circle().stroke(TCColor.line, lineWidth: 1))
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(TCColor.textSoft)
                )
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, TCSpace.gutter)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    private var todayLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE d 'de' MMMM"
        return f.string(from: .now)
    }

    // MARK: - Widgets

    private var gymWidget: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    TCRing(value: 0.6)
                    Text("3/5").tcNumber(17)
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 5) {
                    Text("GIMNASIO").tcLabel()
                    Text("Empuje · semana 3").tcSection()
                    Text("Hoy toca pecho y hombro").tcBody()
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 7) {
                        Text(day.letter)
                            .font(TCFont.font(11))
                            .foregroundStyle(day.restDay ? TCColor.textFaint : TCColor.textSoft)
                        Group {
                            if day.restDay {
                                Capsule().fill(TCColor.track).frame(width: 7, height: 1.5)
                            } else {
                                Circle()
                                    .fill(day.done ? TCColor.moss : TCColor.track)
                                    .frame(width: 7, height: 7)
                            }
                        }
                        .frame(height: 7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .tcCard(padding: 18)
    }

    private struct DayDot { let letter: String; let done: Bool; let restDay: Bool }

    private var weekDays: [DayDot] {
        [.init(letter: "L", done: true, restDay: false),
         .init(letter: "M", done: true, restDay: false),
         .init(letter: "X", done: true, restDay: false),
         .init(letter: "J", done: false, restDay: false),
         .init(letter: "V", done: false, restDay: false),
         .init(letter: "S", done: false, restDay: true),
         .init(letter: "D", done: false, restDay: true)]
    }

    private func mediumWidget(label: String, value: String,
                              caption: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).tcLabel()
            Text(value).tcNumber(22)
            Text(caption).tcMicro()
            TCProgressBar(value: progress, height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard()
    }

    private var calendarWidget: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("CALENDARIO").tcLabel()
            Text("12 nov").tcNumber(22)
            Text("Renovar dominio").tcMicro()
            HStack(spacing: 6) {
                Circle().fill(TCColor.sand).frame(width: 7, height: 7)
                Text("en 3 días").tcMicro()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tcCard()
    }

    // MARK: - Barra de secciones

    // Nombres propios: `Section` y `Tab` ya existen en SwiftUI y taparlos da sustos.
    private struct HomeSection: Identifiable {
        let id = UUID()
        let name: String
        let symbol: String
    }

    private let sections: [HomeSection] = [
        .init(name: "Armario", symbol: "hanger"),
        .init(name: "Caprichos", symbol: "sparkles"),
        .init(name: "Proyectos", symbol: "flag"),
        .init(name: "Formación", symbol: "lightbulb"),
        .init(name: "Biblioteca", symbol: "books.vertical"),
        .init(name: "Finanzas", symbol: "circle.circle")
    ]

    private var sectionsBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 14) {
                ForEach(sections) { section in
                    Button {} label: {
                        VStack(spacing: 8) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 20, weight: .light))
                                .frame(height: 23)
                                .foregroundStyle(TCColor.text)
                            Text(section.name)
                                .font(TCFont.font(10))
                                .foregroundStyle(TCColor.textSoft)
                        }
                        .frame(width: 48)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .scrollIndicators(.hidden)
        .background(TCColor.card)
        .clipShape(RoundedRectangle(cornerRadius: TCRadius.bar, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TCRadius.bar, style: .continuous)
                .stroke(TCColor.line, lineWidth: 1)
        )
    }

    // MARK: - Los cuatro botones

    private struct HomeTab { let name: String; let symbol: String }

    private let tabs: [HomeTab] = [
        .init(name: "Inicio", symbol: "house"),
        .init(name: "Buscar", symbol: "magnifyingglass"),
        .init(name: "Añadir", symbol: "plus.circle"),
        .init(name: "Ajustes", symbol: "slider.horizontal.3")
    ]

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button { selectedTab = index } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 20, weight: .light))
                        Text(tab.name).font(TCFont.font(10, index == selectedTab ? .medium : .regular))
                    }
                    .foregroundStyle(index == selectedTab ? TCColor.moss : TCColor.textMicro)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
