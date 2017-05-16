// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Gyutou",
    dependencies: [
        .Package(url: "https://github.com/krzyzanowskim/CryptoSwift", majorVersion: 0, minor: 6),
    ]
)
