// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Recon",
    platforms: [
        .iOS(.v18)
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
    dependencies: [
        .package(url: "https://github.com/guardian/qalam.git", from: "1.0.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Recon",
            dependencies: [
                .product(name: "Qalam", package: "qalam")
            ]
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
