// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CloudKey",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CloudKey", targets: ["CloudKey"])
    ],
    targets: [
        .executableTarget(
            name: "CloudKey",
            path: "Sources",
            resources: [
                .process("../Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "CloudKeyTests",
            dependencies: ["CloudKey"]
        )
    ]
)
