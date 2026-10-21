// swift-tools-version: 5.9
import PackageDescription

// The app target links AppKit and IOKit, so it is only part of the package on macOS.
// MacJanitorCore and its tests build anywhere Foundation is available.
var products: [Product] = [
    .library(name: "MacJanitorCore", targets: ["MacJanitorCore"]),
]
var targets: [Target] = [
    .target(
        name: "MacJanitorCore",
        path: "Sources/MacJanitorCore"
    ),
    .testTarget(
        name: "MacJanitorTests",
        dependencies: ["MacJanitorCore"],
        path: "Tests/MacJanitorTests"
    ),
]

#if os(macOS)
products.append(.executable(name: "MacJanitor", targets: ["MacJanitor"]))
targets.append(
    .executableTarget(
        name: "MacJanitor",
        dependencies: ["MacJanitorCore"],
        path: "Sources/MacJanitor",
        exclude: [".DS_Store"],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("IOKit"),
        ]
    )
)
#endif

let package = Package(
    name: "MacJanitor",
    platforms: [
        .macOS(.v12)
    ],
    products: products,
    targets: targets
)
