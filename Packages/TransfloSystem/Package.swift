// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TransfloSystem",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TransfloSystem", targets: ["TransfloSystem"])
    ],
    dependencies: [
        .package(path: "../TransfloDomain")
    ],
    targets: [
        .target(name: "TransfloSystem", dependencies: ["TransfloDomain"]),
        .testTarget(name: "TransfloSystemTests", dependencies: ["TransfloSystem"])
    ]
)
