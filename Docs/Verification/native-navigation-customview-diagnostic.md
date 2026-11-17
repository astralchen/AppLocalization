# 原生 customView 导航项诊断（历史记录，已修复）

后续已用 invalidateIntrinsicContentSize 修复并加入正式 UIKitCustomNavigationItemTests 和真实 App UI 回归，见 [修复验证清单](custom-navigation-fix.json)。以下保留修复前的失败现象及尝试，不代表当前状态；原失败函数仍保留供比较。

环境：iPhone 18 Pro、iOS 27.2 模拟器，Xcode 包测试宿主。

新增诊断将两个 UIButton 作为 UIBarButtonItem.customView，分别安装到原生 leftBarButtonItem 和 rightBarButtonItem。窗口挂载后，在阿拉伯语和英语之间反复切换，使用公开 convert(_:to:) 检查两个按钮的实际水平位置。

结果：Scene、导航栏及按钮的布局方向 traits 正确更新，但 customView 的位置仍停留在原侧。下一轮主队列、setNeedsLayout、setNeedsUpdateConstraints 和重复调用原生导航项 setter 均未使这项诊断通过。没有遍历私有子视图，没有替换系统手势、导航栈或按钮实例。

本轮两个示例使用普通 UIBarButtonItem，未使用该 customView 场景。真实 App UI 测试已检查同一个普通导航栏关闭按钮在英／中／阿拉伯语热切换后的物理位置；该测试通过。包正式回归检查普通导航项的身份、槽位和方向投递，不用它替代像素验收。

当时 customView 场景尚未解决，未包含在该轮通过结论中。没有添加预期失败标记，也没有把清空重建导航项作为框架通用行为。复现函数保存在同目录的 native-navigation-customview-diagnostic.swift.txt，可放入 UIKitLocalizationInfrastructureTests 中运行；它使用该测试类已有的 makeController()。

失败结果包和尝试记录列于 native-surface-cleanup.json。
