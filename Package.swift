// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Gyutou",
    products: [
        .library(name: "Gyutou", targets: ["Gyutou"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "0.7.2")
    ],
    targets: [
        .target(
            name: "Gyutou",
            dependencies: ["CryptoSwift"],
            path: "Sources"
        )
    ]
)
