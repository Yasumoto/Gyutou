// swift-tools-version:4.1

import PackageDescription

let package = Package(
    name: "Gyutou",
    products: [
        .library(name: "Gyutou", targets: ["Gyutou"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "Gyutou",
            dependencies: ["CryptoSwift"]
        )
    ]
)
