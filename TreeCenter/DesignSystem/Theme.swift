import SwiftUI
import UIKit

// Paleta de Tree Center.
// Fondo oscuro neutro, musgo como único color de marca, y azul/arena/arcilla/lila
// reservados para distinguir carteras y aros: nunca para decorar.
// Cada token trae su valor en claro y en oscuro; la app sigue al sistema.

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// Un color que cambia solo con el tema del iPhone.
    static func tc(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum TCColor {
    // Superficies
    static let bg         = Color.tc(light: 0xF6F6F4, dark: 0x0D0E0E)
    static let card       = Color.tc(light: 0xFFFFFF, dark: 0x161817)
    static let cardSunken = Color.tc(light: 0xF1F1EE, dark: 0x121413)
    static let well       = Color.tc(light: 0xECEDE9, dark: 0x0F1110)

    // Líneas
    static let line       = Color.tc(light: 0xE8E9E5, dark: 0x1F2321)
    static let lineStrong = Color.tc(light: 0xD3D5D0, dark: 0x2A2E2C)
    static let track      = Color.tc(light: 0xECEDE9, dark: 0x232724)

    // Texto
    static let text       = Color.tc(light: 0x141715, dark: 0xF2F3F0)
    static let textSoft   = Color.tc(light: 0x5D635F, dark: 0xA8AEA9)
    static let textMicro  = Color.tc(light: 0x6B716D, dark: 0x7E847F)
    static let textFaint  = Color.tc(light: 0x9AA09C, dark: 0x5A605C)

    // Marca
    static let moss       = Color.tc(light: 0x3E6B4E, dark: 0x7FB38C)
    static let mossWell   = Color.tc(light: 0xEAF1EC, dark: 0x11150F)
    /// Lo que va escrito encima del musgo.
    static let onMoss     = Color.tc(light: 0xFFFFFF, dark: 0x0D0E0E)

    // Solo para datos: carteras, aros, tipos de fecha.
    static let blue       = Color.tc(light: 0x44628A, dark: 0x7A9CC6)
    static let sand       = Color.tc(light: 0x8A6E2E, dark: 0xC9A86A)
    static let clay       = Color.tc(light: 0x8A4B31, dark: 0xC97F5E)
    static let lilac      = Color.tc(light: 0x6B5B99, dark: 0x9B8CC4)
    static let neutralData = Color.tc(light: 0x5C665F, dark: 0xE6E8E3)

    /// El orden en que se reparten los colores a las carteras nuevas.
    static let dataPalette: [Color] = [moss, blue, sand, clay, lilac, neutralData]
}

enum TCRadius {
    static let chip: CGFloat = 999
    static let control: CGFloat = 15
    static let card: CGFloat = 20
    static let cardLarge: CGFloat = 22
    static let bar: CGFloat = 24
    static let sheet: CGFloat = 28
}

enum TCSpace {
    static let gutter: CGFloat = 20
    static let tight: CGFloat = 10
    static let row: CGFloat = 12
    static let block: CGFloat = 20
}
