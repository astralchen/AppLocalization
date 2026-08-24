import SwiftUI
import AppLocalization

struct DemoRootView: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    @State private var isSheetPresented = false
    @State private var isPushPresented = false

    private var demoItemTitles: [String] {
        (1...DemoSurfaceLayout.itemCount).map {
            resolver.string("collection.item.\($0)", bundle: .main)
        }
    }

    var body: some View {
        NavigationView {
            List {
                LanguageSelectionSection(
                    localizationController: localizationController,
                    resolver: resolver
                )
                Section("SwiftUI") {
                    SwiftUIDemoCard(
                        title: resolver.string("swiftui.instant", bundle: .main),
                        message: resolver.string("swiftui.body", bundle: .main),
                        sheetButtonTitle: resolver.string("show.sheet", bundle: .main),
                        pushButtonTitle: resolver.string("pop.open", bundle: .main),
                        itemTitles: demoItemTitles,
                        showSheet: showSheet,
                        showPushPage: showPushPage
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section("UIKit") {
                    UIKitDemoRepresentable(
                        localizationController: localizationController,
                        resolver: resolver,
                        onPushRequested: showPushPage
                    )
                    .frame(minHeight: DemoSurfaceLayout.minimumCardHeight)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                GestureDirectionDemoView(
                    localizationController: localizationController,
                    resolver: resolver
                )
            }
            .navigationTitle(resolver.string("demo.title", bundle: .main))
            // `NavigationView` 背后的 `UINavigationController` 必须在入栈前同步语义方向。
            // 仅在目标页面配置会太晚，阿拉伯文布局的出栈动画仍可能从左向右移动。
            .background(
                NavigationPopGestureConfigurator(
                    layoutDirection: localizationController.layoutDirection
                )
                .frame(width: 0, height: 0)
            )
            .toolbar {
                // 返回操作位于语义前缘，而不是固定物理右侧；图标方向由
                // `DirectionalLayout` 根据当前布局方向确定。
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(
                        systemName: DirectionalLayout.backChevronSystemName(
                            layoutDirection: localizationController.layoutDirection
                        )
                    )
                    .accessibilityLabel(
                        resolver.string("nav.direction.icon", bundle: .main)
                    )
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
                DemoSheetView(
                    localizationController: localizationController,
                    resolver: resolver
                )
            }
        }
    }

    private func showSheet() {
        isSheetPresented = true
    }

    private func showPushPage() {
        isPushPresented = true
    }
}

private struct LanguageSelectionSection: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    private var currentLanguageValue: String {
        guard localizationController.followsSystemLocale else {
            return localizationController.currentLocale.identifier
        }

        let followSystem = resolver.string("language.follow.system", bundle: .main)
        return "\(followSystem) (\(localizationController.currentLocale.identifier))"
    }

    private var systemResolvedLocaleSubtitle: String {
        localizationController.currentLocale.localizedDisplayName(
            preferredBy: localizationController.currentLocale
        )
    }

    var body: some View {
        Section(resolver.string("language.section", bundle: .main)) {
            Button(action: followSystemLocale) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // “跟随系统”是设置状态，因此主标题跟随当前应用语言刷新。
                        Text(resolver.string("language.follow.system", bundle: .main))
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
                Button(action: { select(locale) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // 主标题使用候选语言自身方向，避免受当前应用布局方向影响。
                            Text(locale.nativeDisplayName)
                                .environment(
                                    \.layoutDirection,
                                    locale.layoutDirection.swiftUILayoutDirection
                                )
                            Text(
                                locale.localizedDisplayName(
                                    preferredBy: localizationController.currentLocale
                                )
                            )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !localizationController.followsSystemLocale
                            && locale == localizationController.currentLocale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            DemoKeyValueRow(
                title: resolver.string("current.language", bundle: .main),
                value: currentLanguageValue
            )
            DemoKeyValueRow(
                title: resolver.string("direction", bundle: .main),
                value: localizationController.layoutDirection == .rightToLeft ? "RTL" : "LTR"
            )
        }
    }

    private func followSystemLocale() {
        localizationController.setFollowsSystemLocale()
    }

    private func select(_ locale: AppLocale) {
        localizationController.setLocale(identifier: locale.identifier)
    }
}

private struct SwiftUIDemoCard: View {
    let title: String
    let message: String
    let sheetButtonTitle: String
    let pushButtonTitle: String
    let itemTitles: [String]
    let showSheet: () -> Void
    let showPushPage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DemoSurfaceLayout.spacing) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)

            actionButton(sheetButtonTitle, action: showSheet)
            actionButton(pushButtonTitle, action: showPushPage)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DemoSurfaceLayout.spacing) {
                    ForEach(Array(itemTitles.enumerated()), id: \.offset) { _, title in
                        Text(title)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .frame(
                                width: DemoSurfaceLayout.itemWidth,
                                height: DemoSurfaceLayout.itemHeight
                            )
                            .background(Color(uiColor: .systemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: DemoSurfaceLayout.cornerRadius)
                                    .stroke(Color(uiColor: .separator), lineWidth: 1)
                            }
                    }
                }
            }
            .frame(height: DemoSurfaceLayout.collectionHeight)
        }
        .padding(DemoSurfaceLayout.contentInset)
        .frame(minHeight: DemoSurfaceLayout.minimumCardHeight)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DemoSurfaceLayout.cornerRadius))
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: DemoSurfaceLayout.buttonHeight)
                .contentShape(Rectangle())
        }
        // 同一 `List` 行中的多个自动样式按钮可能共享行点击事件。
        // 使用无边框样式可使两个呈现操作保持独立。
        .buttonStyle(.borderless)
    }
}

private struct DemoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(resolver.string("sheet.message", bundle: .main))
                    .font(.body)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle(resolver.string("sheet.title", bundle: .main))
            .toolbar {
                // Sheet 边界已经显式注入应用方向，因此保持语义前缘即可；
                // SwiftUI 会在 LTR/RTL 下分别解析到左侧/右侧。
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(resolver.string("close", bundle: .main)) {
                        dismiss()
                    }
                }
            }
            // SwiftUI 环境会更新内容方向，工作表的 UIKit 导航容器也需使用相同语义方向。
            .background(
                NavigationPopGestureConfigurator(
                    layoutDirection: localizationController.layoutDirection
                )
                .frame(width: 0, height: 0)
            )
        }
        // Sheet content may be materialized after the last app-wide change
        // notification. Inject the current values at this presentation
        // boundary instead of relying on the presenting hierarchy to carry
        // them into a newly created host.
        .environment(\.locale, localizationController.locale)
        .environment(
            \.layoutDirection,
            localizationController.layoutDirection.swiftUILayoutDirection
        )
    }
}

private struct DemoKeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

enum DemoSurfaceLayout {
    static let contentInset: CGFloat = 16
    static let spacing: CGFloat = 12
    static let cornerRadius: CGFloat = 8
    static let buttonHeight: CGFloat = 32
    static let itemWidth: CGFloat = 132
    static let itemHeight: CGFloat = 64
    static let collectionHeight: CGFloat = 76
    static let minimumCardHeight: CGFloat = 310
    static let itemCount = 3
}
