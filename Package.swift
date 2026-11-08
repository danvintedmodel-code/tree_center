// swift-tools-version: 5.9
import PackageDescription

// El código de Tree Center vive como paquete para poder compilarlo sin proyecto de
// Xcode: así la integración continua lo tipa en cada push y los errores llegan solos.
//
//   TreeCenterCore  lógica pura, sin UIKit ni SwiftUI. Es la que lleva tests.
//   TreeCenterData  los modelos de SwiftData y el esquema.
//   TreeCenterKit   todo lo visual: diseño, Acceso y Home.
//
// La app (el `@main`) queda fuera del paquete, en TreeCenter/TreeCenterApp.swift:
// un target de librería no es sitio para un punto de entrada.

let package = Package(
    name: "TreeCenter",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TreeCenterCore", targets: ["TreeCenterCore"]),
        .library(name: "TreeCenterData", targets: ["TreeCenterData"]),
        .library(name: "TreeCenterKit", targets: ["TreeCenterKit"])
    ],
    targets: [
        .target(
            name: "TreeCenterCore",
            path: "TreeCenterCore"
        ),
        .target(
            name: "TreeCenterData",
            path: "TreeCenterData"
        ),
        .target(
            name: "TreeCenterKit",
            dependencies: ["TreeCenterCore", "TreeCenterData"],
            path: "TreeCenter",
            exclude: ["README.md", "TreeCenterApp.swift"]
        ),
        .testTarget(
            name: "TreeCenterCoreTests",
            dependencies: ["TreeCenterCore"],
            path: "Tests/TreeCenterCoreTests"
        ),
        .testTarget(
            name: "TreeCenterDataTests",
            dependencies: ["TreeCenterData"],
            path: "Tests/TreeCenterDataTests"
        )
    ]
)
