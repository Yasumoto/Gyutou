// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "Gyutou",
    products: [
        .library(name: "Gyutou", targets: ["Gyutou"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "0.15.0")
    ],
    targets: [
        .target(
            name: "Gyutou",
            dependencies: ["CryptoSwift"]
        )
    ]
)
