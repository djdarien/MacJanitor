// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacJanitor",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "MacJanitor",
            targets: ["MacJanitor"]
        ),
        .library(
            name: "MacJanitorCore",
            targets: ["MacJanitorCore"]
        ),
    ],
    targets: [
        .target(
            name: "MacJanitorCore",
            path: "Sources/MacJanitorCore"
        ),
        .executableTarget(
            name: "MacJanitor",
            dependencies: ["MacJanitorCore"],
            path: "Sources/MacJanitor",
            exclude: [".DS_Store"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(
            name: "MacJanitorTests",
            dependencies: ["MacJanitorCore"],
            path: "Tests/MacJanitorTests"
        ),
    ]
)
