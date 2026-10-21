// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TransfloDomain",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "TransfloDomain", targets: ["TransfloDomain"]),
        .library(name: "TransfloDomainTestSupport", targets: ["TransfloDomainTestSupport"])
    ],
    targets: [
        .target(name: "TransfloDomain"),
        .target(name: "TransfloDomainTestSupport", dependencies: ["TransfloDomain"]),
        .testTarget(name: "TransfloDomainTests", dependencies: ["TransfloDomain", "TransfloDomainTestSupport"])
    ]
)
