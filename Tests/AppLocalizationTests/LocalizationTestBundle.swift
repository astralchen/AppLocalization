import Foundation

/// 用真实 Bundle 元数据构造测试资源包，不向生产控制器增加语言列表注入接口。
func localizationTestBundle(_ identifiers: [String], developmentLocalization: String = "en-US") -> Bundle {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalizationTests-\(UUID().uuidString).bundle", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "tests.localization.\(UUID().uuidString)",
            "CFBundleDevelopmentRegion": developmentLocalization,
            "CFBundleLocalizations": identifiers
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Info.plist"))
        guard let bundle = Bundle(url: url) else { fatalError("无法创建测试资源包") }
        return bundle
    } catch {
        fatalError("无法创建测试资源包：\(error)")
    }
}
