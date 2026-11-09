import PhotosUI
import SwiftUI
import UIKit

// El hueco de la foto. Es el mismo en la receta, en la prenda, en el capricho y
// en el lugar: si no hay foto, un dibujo apagado; si hay, la foto llenando el
// hueco. Y siempre los dos botones, cámara y galería.
//
// La foto no se guarda tal cual: pasa por `TCImage` para que no entren cuatro
// megas por cada receta. Ver TCImage.swift.

/// Mete en `data` la foto elegida, ya reducida. Si el archivo no se puede leer
/// o no es una imagen, se queda la que hubiera: es mejor que vaciar el hueco
/// sin avisar.

func loadPhoto(_ item: PhotosPickerItem?, into data: Binding<Data?>) {
    guard let item else { return }

    Task { @MainActor in
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let prepared = TCImage.prepared(raw) else { return }
        data.wrappedValue = prepared
    }
}

struct PhotoWell: View {
    @Binding var data: Data?

    var height: CGFloat = 220
    var radius: CGFloat = 22
    var symbol: String = "photo"
    var hint: String = "Sin foto"
    /// `.fill` recorta para llenar y `.fit` deja ver la prenda entera con su
    /// fondo recortado. Las prendas quieren `.fit`.
    var mode: ContentMode = .fill

    @State private var picked: PhotosPickerItem?
    @State private var camera = false

    var body: some View {
        ZStack {
            canvas
            controls
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(TCColor.line, lineWidth: 1)
        )
        .onChange(of: picked) { _, new in loadPhoto(new, into: $data) }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { image in data = TCImage.prepared(image) }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var canvas: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: mode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            ZStack {
                TCColor.cardSunken
                VStack(spacing: 9) {
                    Image(systemName: symbol)
                        .font(.system(size: 34, weight: .ultraLight))
                        .foregroundStyle(TCColor.textFaint)
                    Text(hint).tcMicro()
                }
            }
        }
    }

    private var controls: some View {
        VStack {
            if data != nil {
                HStack {
                    Spacer()
                    Button { data = nil } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TCColor.text)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Quitar la foto")
                }
                .padding(12)
            }

            Spacer()

            HStack(spacing: 8) {
                Spacer()

                if CameraPicker.isAvailable {
                    Button { camera = true } label: { circle("camera") }
                        .accessibilityLabel("Hacer una foto")
                }

                PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) {
                    circle("photo.on.rectangle")
                }
                .accessibilityLabel("Elegir de la galería")
            }
            .padding(12)
        }
    }

    private func circle(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .light))
            .foregroundStyle(TCColor.text)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
    }
}

/// La versión de una línea, para cuando no cabe un hueco grande: una miniatura
/// y, al lado, de dónde sacarla. El recibo del gasto es esto.
struct PhotoRow: View {
    @Binding var data: Data?

    var title: String
    var symbol: String = "doc.text.viewfinder"

    @State private var picked: PhotosPickerItem?
    @State private var camera = false

    var body: some View {
        HStack(spacing: 11) {
            thumb

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TCFont.font(13))
                    .foregroundStyle(TCColor.text)
                Text(weightLine)
                    .font(TCFont.font(10))
                    .foregroundStyle(TCColor.textMicro)
            }

            Spacer(minLength: 8)

            if data == nil {
                if CameraPicker.isAvailable {
                    Button { camera = true } label: { small("camera") }
                        .accessibilityLabel("Hacer una foto")
                }
                PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) {
                    small("photo.on.rectangle")
                }
                .accessibilityLabel("Elegir de la galería")
            } else {
                Button { data = nil } label: { small("xmark") }
                    .accessibilityLabel("Quitar la foto")
            }
        }
        .padding(11)
        .background(TCColor.well)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onChange(of: picked) { _, new in loadPhoto(new, into: $data) }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { image in data = TCImage.prepared(image) }
                .ignoresSafeArea()
        }
    }

    private var weightLine: String {
        guard let data else { return "sin adjuntar" }
        return TCImage.weight(data)
    }

    @ViewBuilder
    private var thumb: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        } else {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(TCColor.textFaint)
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(TCColor.lineStrong,
                                      style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
        }
    }

    private func small(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .light))
            .foregroundStyle(TCColor.textSoft)
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(TCColor.lineStrong, lineWidth: 1))
    }
}

/// Una miniatura sin más, para las filas de una lista.
struct PhotoThumb: View {
    let data: Data?
    var side: CGFloat = 34
    var radius: CGFloat = 9
    var symbol: String = "photo"

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            Image(systemName: symbol)
                .font(.system(size: side * 0.4, weight: .ultraLight))
                .foregroundStyle(TCColor.textFaint)
                .frame(width: side, height: side)
                .background(TCColor.cardSunken)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}
