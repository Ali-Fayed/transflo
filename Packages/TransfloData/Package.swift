// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TransfloData",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "TransfloData", targets: ["TransfloData"])
    ],
    dependencies: [
        .package(path: "../TransfloDomain")
    ],
    targets: [
        .target(name: "TransfloData", dependencies: ["TransfloDomain"], resources: [.process("Resources")]),
        .testTarget(
            name: "TransfloDataTests",
            dependencies: ["TransfloData", .product(name: "TransfloDomainTestSupport", package: "TransfloDomain")]
        )
    ]
)
