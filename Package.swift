// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "CloudKey",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CloudKey", targets: ["CloudKey"])
    ],
    dependencies: [
        .package(url: "https://github.com/lachlanbell/SwiftOTP", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CloudKey",
            dependencies: ["SwiftOTP"],
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
