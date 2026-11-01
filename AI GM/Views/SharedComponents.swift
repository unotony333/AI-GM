//
//  SharedComponents.swift
//  AI GM
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Action Button Style

enum ActionButtonStyle {
    case primary
    case secondary
}

struct GameButtonStyle: ButtonStyle {
    let kind: ActionButtonStyle
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 16)
            .background(background, in: shape)
            .overlay {
                if kind == .secondary {
                    shape.strokeBorder(Palette.hairline, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        guard isEnabled else { return Palette.sageDim }
        return kind == .primary ? Palette.candleInk : Palette.vellum
    }

    private var background: Color {
        switch kind {
        case .primary:
            return isEnabled ? Palette.candle : Palette.feltRaised
        case .secondary:
            return isEnabled ? Palette.feltRaised : Palette.feltRaised.opacity(0.5)
        }
    }
}

// MARK: - Card Modifier

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.feltRaised.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Shared UI Helpers

func sectionTitle(_ text: String) -> some View {
    Text(text)
        .serifFont(.heading)
        .foregroundStyle(Palette.vellum)
}

func fieldLabel(_ text: String) -> some View {
    Text(text)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Palette.sage)
}

func headerChip(title: String, color: Color) -> some View {
    Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
}

func actionButton(title: String, style: ActionButtonStyle, isDisabled: Bool, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
        .buttonStyle(GameButtonStyle(kind: style))
        .disabled(isDisabled)
}

/// Firebase 尚未連線時的提示列
func connectionNotice(_ message: String, onRetry: @escaping () -> Void) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
        Image(systemName: "wifi.exclamationmark")
            .foregroundStyle(Palette.candle)

        Text(message)
            .font(.footnote)
            .foregroundStyle(Palette.vellum.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)

        Button("重試", action: onRetry)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.candle)
    }
    .padding(14)
    .background(Palette.candle.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Palette.candle.opacity(0.3), lineWidth: 1)
    )
}

// MARK: - Label Helpers

func phaseLabel(_ phase: CampaignPhase) -> String {
    switch phase {
    case .lobby: return "大廳"
    case .starting: return "開場中"
    case .collectingActions: return "等待行動"
    case .resolvingTurn: return "結算中"
    case .finished: return "已結束"
    }
}

func phaseColor(_ phase: CampaignPhase) -> Color {
    switch phase {
    case .lobby: return Palette.sage
    case .starting: return Palette.candle
    case .collectingActions: return Palette.moss
    case .resolvingTurn: return Palette.candle
    case .finished: return Palette.sageDim
    }
}

func formatLabel(_ format: AIAPIFormat) -> String {
    switch format {
    case .openAICompatible: return "OpenAI"
    case .ollama: return "Ollama"
    }
}

func messageKindLabel(_ kind: CampaignMessageKind) -> String {
    switch kind {
    case .opening: return "開場"
    case .system: return "系統"
    case .narration: return "GM"
    case .player: return "玩家"
    }
}

// MARK: - Reusable Input Components

private struct InputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Palette.candle)
            .background(Palette.feltSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
    }
}

struct GameTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Palette.sageDim))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(Palette.vellum)
            .padding(14)
            .modifier(InputFieldModifier())
    }
}

struct GameSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(Palette.sageDim))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(Palette.vellum)
            .padding(14)
            .modifier(InputFieldModifier())
    }
}

struct GameTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat? = nil

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Palette.sageDim), axis: .vertical)
            .textInputAutocapitalization(.sentences)
            .foregroundStyle(Palette.vellum)
            .lineLimit(2...7)
            .padding(14)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .modifier(InputFieldModifier())
    }
}
