import SwiftUI
import AppLocalization

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
                    // 此拖拽区不执行真正的出栈操作，仅验证物理滑动到语义返回的映射。
                    // 从左向右布局时向右滑动表示返回；从右向左布局时则向左滑动。
                    // 生产环境中的边缘手势和入栈、出栈动画也应使用 `DirectionalLayout`。
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
        // 根页面已在入栈前同步 `UINavigationController` 方向；
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
