import SwiftUI

extension Color {
    static let wearWiseInk = Color(uiColor: .label)
    static let wearWiseBackground = Color(uiColor: .systemBackground)
    static let wearWiseSecondary = Color(uiColor: .secondaryLabel)
    static let wearWiseSurface = Color(uiColor: .secondarySystemBackground)
    static let wearWiseBorder = Color.primary.opacity(0.18)
}

struct WearWisePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(
                isEnabled
                    ? Color(uiColor: .systemBackground)
                    : Color.wearWiseInk
            )
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 20)
            .background(
                isEnabled ? Color.wearWiseInk : Color.wearWiseBackground,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.wearWiseInk,
                        style: StrokeStyle(
                            lineWidth: isEnabled ? 0 : 2,
                            dash: isEnabled ? [] : [6, 4]
                        )
                    )
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct WearWiseSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.wearWiseInk)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 18)
            .background(
                Color.wearWiseBackground,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.wearWiseInk,
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: isEnabled ? [] : [6, 4]
                        )
                    )
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct WearWiseCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                Color.wearWiseSurface,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.wearWiseBorder, lineWidth: 1)
            }
    }
}

extension View {
    func wearWiseCard() -> some View {
        modifier(WearWiseCardModifier())
    }
}
