/// 刷新页面拥有的标题、文案、菜单和业务配置。
/// 窗口协调器先同步容器方向，再调用已加载页面的此方法。
@MainActor
public protocol UIKitLocalizationApplying: AnyObject {
    func applyLocalization(_ update: LocalizationUpdate)
}
