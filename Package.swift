// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "AppLocalization",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AppLocalization",
            targets: ["AppLocalization"]
        )
    ],
    targets: [
        .target(
            name: "AppLocalization"
        ),
        .testTarget(
            name: "AppLocalizationTests",
            dependencies: ["AppLocalization"],
            resources: [
                .process("Resources")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
