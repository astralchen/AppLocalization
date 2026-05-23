// swift-tools-version: 6.0
import PackageDescription

// Swift 6 已经启用严格并发语义；这里再显式加入完整并发检查 flag，
// 让普通 `swift test` 也能像 CI 一样暴露 Sendable、actor isolation 和
// NotificationCenter observer 闭包等潜在数据竞争问题。
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
