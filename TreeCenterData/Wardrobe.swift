import Foundation
import SwiftData

// Armario. Cada prenda guarda dos cosas distintas: el PNG recortado que se ve en
// la tira de abajo, y el nombre de la malla 3D que se le monta al maniquí.
// Son archivos diferentes y conviene no confundirlos.

@Model
public final class Garment {
    public var name: String = ""
    public var categoryRaw: String = GarmentCategory.hoodies.rawValue
    public var colorRaw: String = PaletteColor.neutral.rawValue
    /// Malla para el maniquí. Mientras no exista, la prenda solo vive en 2D.
    public var meshName: String?
    public var isWorn: Bool = false
    public var createdAt: Date = Date()

    @Attribute(.externalStorage) public var image: Data?

    @Relationship(inverse: \Outfit.garments)
    public var outfits: [Outfit] = []

    public init(name: String = "", category: GarmentCategory = .hoodies,
                color: PaletteColor = .neutral, meshName: String? = nil) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.colorRaw = color.rawValue
        self.meshName = meshName
        self.createdAt = Date()
    }

    public var category: GarmentCategory {
        GarmentCategory(rawValue: categoryRaw) ?? .hoodies
    }

    public var color: PaletteColor { PaletteColor(rawValue: colorRaw) ?? .neutral }
}

@Model
public final class Outfit {
    public var name: String = ""
    public var createdAt: Date = Date()

    public var garments: [Garment] = []

    public init(name: String = "", garments: [Garment] = []) {
        self.name = name
        self.garments = garments
        self.createdAt = Date()
    }
}
