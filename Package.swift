// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Recon",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Recon",
            targets: ["Recon"]
        ),
        .plugin(
            name: "ReconKeygenPlugin",
            targets: ["ReconKeygenPlugin"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Recon"
        ),
        .executableTarget(
            name: "recon-keygen"
        ),
        .plugin(
            name: "ReconKeygenPlugin",
            capability: .buildTool(),
            dependencies: ["recon-keygen"]
        ),
        .testTarget(
            name: "ReconTests",
            dependencies: ["Recon"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
