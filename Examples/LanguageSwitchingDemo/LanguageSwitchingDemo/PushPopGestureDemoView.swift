import SwiftUI

struct PushPopGestureDemoView: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    @State private var translationX: CGFloat = 0
    @State private var isBackSwipe = false

    var body: some View {
        List {
            Section(resolver.string("pop.section", bundle: .main)) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(resolver.string("pop.description", bundle: .main))
                        .font(.body)
                    keyValueRow(
                        title: resolver.string("direction", bundle: .main),
                        value: localizationController.layoutDirection == .rightToLeft ? "RTL" : "LTR"
                    )
                    keyValueRow(
                        title: resolver.string("pop.expected.edge", bundle: .main),
                        value: expectedEdgeText
                    )
                }
                .padding(.vertical, 4)
            }

            Section(resolver.string("pop.drag.section", bundle: .main)) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isBackSwipe ? Color.green.opacity(0.18) : Color.secondary.opacity(0.14))
                    .frame(height: 132)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: DirectionalLayout.backChevronSystemName(layoutDirection: localizationController.layoutDirection))
                                .font(.title2)
                            Text(isBackSwipe ? resolver.string("pop.detected", bundle: .main) : resolver.string("pop.not.detected", bundle: .main))
                                .font(.headline)
                            Text(translationText)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding()
                    }
                    // 这个拖拽区不负责真正 pop，只验证“物理滑动 -> 语义返回”的判断。
                    // LTR 下向右滑是返回；RTL 下向左滑是返回。生产里的自定义
                    // edge-pan、push/pop 动画也应使用同一套 DirectionalLayout 逻辑。
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { value in
                                translationX = value.translation.width
                                isBackSwipe = DirectionalLayout.isBackSwipe(
                                    translationX: value.translation.width,
                                    layoutDirection: localizationController.layoutDirection
                                )
                            }
                            .onEnded { value in
                                translationX = value.translation.width
                                isBackSwipe = DirectionalLayout.isBackSwipe(
                                    translationX: value.translation.width,
                                    layoutDirection: localizationController.layoutDirection
                                )
                            }
                    )
            }
        }
        .navigationTitle(resolver.string("pop.page.title", bundle: .main))
        // 兜底配置：根页面已经在 push 发生前同步 UINavigationController 方向；
        // 目标页继续挂一次，覆盖语言切换后仍停留在栈内页面的场景。
        .background(
            NavigationPopGestureConfigurator(layoutDirection: localizationController.layoutDirection)
                .frame(width: 0, height: 0)
        )
    }

    private var expectedEdgeText: String {
        switch DirectionalLayout.backSwipeEdge(layoutDirection: localizationController.layoutDirection) {
        case .left:
            return resolver.string("pop.edge.left", bundle: .main)
        case .right:
            return resolver.string("pop.edge.right", bundle: .main)
        }
    }

    private var translationText: String {
        String(format: "translation.x %.0f", translationX)
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
