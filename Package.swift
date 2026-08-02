// swift-tools-version: 6.0
import PackageDescription

// Swift 6 已启用严格并发语义；此处额外加入完整并发检查选项，使普通
// `swift test` 也能像持续集成构建一样暴露 `Sendable`、actor 隔离和
// `NotificationCenter` 观察者闭包等潜在数据竞争问题。
let concurrencySafetySwiftSettings: [SwiftSetting] = [
    .unsafeFlags([
        "-strict-concurrency=complete",
        "-warn-concurrency"
    ])
]

let package = Package(
    name: "AppLocalization",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "AppLocalization",
            targets: ["AppLocalization"]
        )
    ],
    targets: [
        .target(
            name: "AppLocalization",
            swiftSettings: concurrencySafetySwiftSettings
        ),
        .testTarget(
            name: "AppLocalizationTests",
            dependencies: ["AppLocalization"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: concurrencySafetySwiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
