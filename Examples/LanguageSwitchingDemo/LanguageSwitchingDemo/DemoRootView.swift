import SwiftUI

struct DemoRootView: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    @State private var isSheetPresented = false
    @State private var isPushPresented = false

    var body: some View {
        NavigationView {
            List {
                languageSection
                swiftUISection
                UIKitDemoRepresentable(
                    localizationController: localizationController,
                    resolver: resolver,
                    onPushRequested: {
                        isPushPresented = true
                    }
                )
                .frame(minHeight: 310)
                .listRowInsets(EdgeInsets())

                GestureDirectionDemoView(localizationController: localizationController, resolver: resolver)
            }
            .navigationTitle(resolver.string("demo.title", bundle: .main))
            // 修复点：NavigationView 背后的 UINavigationController 必须在 push 发生前
            // 同步 semantic 方向。只在目标 push 页配置会太晚，阿语 RTL 下 pop 动画
            // 仍可能按 LTR 从左向右返回。
            .background(
                NavigationPopGestureConfigurator(layoutDirection: localizationController.layoutDirection)
                    .frame(width: 0, height: 0)
            )
            .toolbar {
                // 修复点：返回语义属于 leading，而不是固定放在右侧。
                // LTR 下 leading 映射到左侧，RTL 下 leading 映射到右侧；
                // 图标方向再由 DirectionalLayout 根据当前布局方向切换。
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: DirectionalLayout.backChevronSystemName(layoutDirection: localizationController.layoutDirection))
                        .accessibilityLabel(resolver.string("nav.direction.icon", bundle: .main))
                }
            }
            .background(
                NavigationLink(
                    destination: PushPopGestureDemoView(
                        localizationController: localizationController,
                        resolver: resolver
                    ),
                    isActive: $isPushPresented,
                    label: { EmptyView() }
                )
                .hidden()
            )
            .sheet(isPresented: $isSheetPresented) {
                NavigationView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(resolver.string("sheet.message", bundle: .main))
                            .font(.body)
                        Spacer()
                    }
                    .padding()
                    .navigationTitle(resolver.string("sheet.title", bundle: .main))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(resolver.string("close", bundle: .main)) {
                                isSheetPresented = false
                            }
                        }
                    }
                }
                .appLocalizationEnvironment(localizationController)
            }
        }
    }

    private var languageSection: some View {
        Section(resolver.string("language.section", bundle: .main)) {
            Button {
                localizationController.setFollowsSystemLocale()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // “跟随系统”是一个选择状态，所以主标题继续跟随当前 App 语言刷新；
                        // 它不像普通语言项那样有固定的 native 名称。
                        Text(resolver.string("language.follow.system", bundle: .main))

                        // 副标题展示系统偏好解析后的真实 App 语言，帮助用户知道当前实际生效的是哪种语言。
                        Text(systemResolvedLocaleSubtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if localizationController.followsSystemLocale {
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(localizationController.supportedLocales, id: \.identifier) { locale in
                Button {
                    localizationController.setLocale(identifier: locale.identifier)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // 主标题使用语言自身名称，保证普通语言项不随当前 App 语言切换而变化。
                            // 同时按该语言自己的排版方向渲染，避免阿语 RTL 环境下把中文/英文视觉反排。
                            Text(locale.nativeDisplayName)
                                .environment(\.layoutDirection, locale.layoutDirection.swiftUILayoutDirection)

                            // 副标题使用当前 App 语言本地化显示，会随语言切换即时刷新；
                            // 这让用户既能看到稳定自名，也能看到当前界面语言下的解释。
                            Text(locale.localizedDisplayName(preferredBy: localizationController.currentLocale))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !localizationController.followsSystemLocale && locale == localizationController.currentLocale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            keyValueRow(
                title: resolver.string("current.language", bundle: .main),
                value: currentLanguageValue
            )
            keyValueRow(
                title: resolver.string("direction", bundle: .main),
                value: localizationController.layoutDirection == .rightToLeft ? "RTL" : "LTR"
            )
        }
    }

    private var currentLanguageValue: String {
        guard localizationController.followsSystemLocale else {
            return localizationController.currentLocale.identifier
        }

        return "\(resolver.string("language.follow.system", bundle: .main)) (\(localizationController.currentLocale.identifier))"
    }

    private var systemResolvedLocaleSubtitle: String {
        localizationController.currentLocale.localizedDisplayName(
            preferredBy: localizationController.currentLocale
        )
    }

    private var swiftUISection: some View {
        Section(resolver.string("swiftui.instant", bundle: .main)) {
            Text(resolver.string("swiftui.body", bundle: .main))
            Button(resolver.string("show.sheet", bundle: .main)) {
                isSheetPresented = true
            }
        }
    }

    private func keyValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
