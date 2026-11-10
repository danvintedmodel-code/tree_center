import SwiftUI
import TreeCenterData
import UIKit

// La tapa de un libro. Si hay foto (la del escaneo o una hecha a mano), la
// foto; si no, una tapa dibujada con su color, el título y el autor, para que
// la estantería nunca tenga huecos grises.

struct LibraryCover: View {
    let book: Book
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            if let data = book.cover, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                drawn
            }

            // El lomo: una franja oscura y un filo de luz. Es lo que convierte
            // un rectángulo en un libro de tapa dura.
            HStack(spacing: 0) {
                Rectangle().fill(Color.black.opacity(0.22)).frame(width: width * 0.08)
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1.2)
                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2,
                                          bottomTrailingRadius: 5, topTrailingRadius: 5,
                                          style: .continuous))
    }

    private var drawn: some View {
        let tint = book.color.swiftUI
        return ZStack {
            Rectangle().fill(tint.opacity(0.85))
            VStack(spacing: height * 0.05) {
                Text(book.title)
                    .font(TCFont.font(max(8, width * 0.13), .semibold))
                    .foregroundStyle(TCColor.bg)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Text(book.author.uppercased())
                    .font(TCFont.font(max(6, width * 0.075)))
                    .tracking(0.5)
                    .foregroundStyle(TCColor.bg.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, height * 0.1)
            .padding(.leading, width * 0.16)
            .padding(.trailing, width * 0.08)
        }
        .frame(width: width, height: height)
    }
}
