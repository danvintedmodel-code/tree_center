import Foundation

// Buscar un libro por su ISBN en Open Library: título, autor, páginas y tapa.
//
// Open Library es la biblioteca abierta del Internet Archive: gratis, sin clave
// y sin cuenta. Lo único que sale del iPhone es el número del código de barras,
// que identifica un libro y no dice nada de ti.
//
// Si no lo encuentra (pasa con ediciones españolas poco comunes), se rellena a
// mano y la tapa se hace con una foto.

struct BookInfo: Equatable {
    var title: String
    var author: String
    var pages: Int?
    var cover: Data?
}

enum BookLookup {

    /// ISBN-10 puede acabar en X; el resto son dígitos. Todo lo demás (guiones,
    /// espacios) sobra.
    static func clean(_ isbn: String) -> String {
        isbn.uppercased().filter { $0.isNumber || $0 == "X" }
    }

    static func find(isbn raw: String) async -> BookInfo? {
        let isbn = clean(raw)
        guard isbn.count == 10 || isbn.count == 13,
              let url = URL(string: "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data")
        else { return nil }

        guard let response = try? await URLSession.shared.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: response.0) as? [String: Any],
              let entry = root["ISBN:\(isbn)"] as? [String: Any]
        else { return nil }

        let title = entry["title"] as? String ?? ""
        let authors = (entry["authors"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let pages = entry["number_of_pages"] as? Int

        var cover: Data?
        if let covers = entry["cover"] as? [String: Any],
           let link = (covers["large"] ?? covers["medium"]) as? String,
           let coverURL = URL(string: link),
           let image = try? await URLSession.shared.data(from: coverURL) {
            // Por el mismo embudo que las fotos: reducida antes de guardarla.
            cover = TCImage.prepared(image.0)
        }

        return BookInfo(title: title, author: authors.joined(separator: ", "), pages: pages, cover: cover)
    }
}
