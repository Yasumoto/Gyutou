// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Gyutou",
    products: [
        .executable(name: "main", targets: ["Gyutou"]),
        .library(name: "Gyutou", targets: ["Gyutou"])
    ],
    dependencies: [
        .package(url: "https://github.com/berenjena-power/CryptoSwift", .branch("swift4"))
    ],
    targets: [
        .target(
            name: "Gyutou",
            dependencies: ["CryptoSwift"],
            path: "Sources"
        )
    ]
)
