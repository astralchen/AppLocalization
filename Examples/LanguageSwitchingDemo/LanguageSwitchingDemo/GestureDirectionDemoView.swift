import SwiftUI
import AppLocalization

struct GestureDirectionDemoView: View {
    @ObservedObject var localizationController: LocalizationController
    let resolver: LocalizedStringResolver

    @State private var lastDirection: SemanticHorizontalDirection?

    var body: some View {
        Section(resolver.string("gesture.title", bundle: .main)) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 96)
                .overlay {
                    VStack(spacing: 8) {
                        Text(resolver.string("gesture.hint", bundle: .main))
                        Text(directionText)
                            .font(.headline)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                }
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            lastDirection = DirectionalLayout.semanticHorizontalDirection(
                                translationX: value.translation.width,
                                layoutDirection: localizationController.layoutDirection
                            )
                        }
                )
        }
    }

    private var directionText: String {
        switch lastDirection {
        case .leading:
            return resolver.string("gesture.leading", bundle: .main)
        case .trailing:
            return resolver.string("gesture.trailing", bundle: .main)
        case nil:
            return resolver.string("gesture.none", bundle: .main)
        }
    }
}
