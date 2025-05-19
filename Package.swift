// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Swish",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Swish",
            targets: ["Swish"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/ggerganov/whisper.cpp", revision: "6266a9f9e56a5b925e9892acf650f3eb1245814d"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Swish", dependencies: [.product(name: "whisper", package: "whisper.cpp")]
        ),
        .testTarget(
            name: "SwishTests",
            dependencies: ["Swish"],
            resources: [
                .copy("Resources/jfk.wav"),
                .copy("Resources/aragorn.wav"),
                .copy("Resources/ggml-tiny.bin"),
            ]
        ),
    ]
)

