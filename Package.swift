// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacJanitorV2",
    platforms: [
        .macOS(.v12) // macOS 12+ (Monterey through Sequoia)
    ],
    products: [
        .executable(
            name: "MacJanitorV2",
            targets: ["MacJanitorV2"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .executableTarget(
            name: "MacJanitorV2",
            dependencies: [],
             path: "Sources/MacJanitor",
             resources: [
                 .process("Resources")
             ]
        ),
        .testTarget(
            name: "MacJanitorTests",
            dependencies: ["MacJanitorV2"],
            path: "Tests/MacJanitorTests"
        ),
    ]
)