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
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Swish", dependencies: ["whisper.xcframework"]
        ),
        .binaryTarget(
            name: "whisper.xcframework",
            url: "https://d1upo2befk76ei.cloudfront.net/whisper.xcframework.1.7.5.rc1.zip",
            checksum: "92733821d24a23890c945ceb83e54b7d3e8543a7d326f0f2e74df0257f72702d"),
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
