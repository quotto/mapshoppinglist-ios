// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AcknowledgementsGenerator",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/FelixHerrmann/swift-package-list.git", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "run",
            dependencies: [
                .product(name: "SwiftPackageList", package: "swift-package-list")
            ]
        )
    ]
)
