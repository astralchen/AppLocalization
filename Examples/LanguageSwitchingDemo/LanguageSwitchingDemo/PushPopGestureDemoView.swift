import SwiftUI
import AppLocalization

struct PushPopGestureDemoView: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    @State private var draft = ""
    @State private var translationX: CGFloat = 0
    @State private var isBackSwipe = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                LanguageSelectionSection(localizationController: localizationController, resolver: resolver)
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
            // 方向变化时只重新创建 List，清除系统列表的镜像缓存。
            .id(localizationController.layoutDirection)
        }
        // List 更新方向时会刷新底层复用内容，并同步结束其中输入框的编辑。
        // 将草稿放在独立的稳定边界，避免 SwiftUI 在更新 List 时回写编辑状态。
        .safeAreaInset(edge: .top, spacing: 0) {
            Group {
                let field = TextField(resolver.string("draft.placeholder", bundle: .main), text: $draft)
                    .multilineTextAlignment(.leading)
                if #available(iOS 26.0, *) {
                    // 以布局环境决定对齐，保留文本自身的书写顺序。
                    field.multilineTextAlignment(strategy: .layoutBased)
                } else {
                    field
                }
            }
            .accessibilityIdentifier("draft.field")
            .padding(16)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationTitle(resolver.string("pop.page.title", bundle: .main))
    }

    private var expectedEdgeText: String {
        let edge = DirectionalLayout.backSwipeRectEdge(layoutDirection: localizationController.layoutDirection)
        return resolver.string(edge == .right ? "pop.edge.right" : "pop.edge.left", bundle: .main)
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
