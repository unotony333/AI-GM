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

    var background: LinearGradient {
        switch self {
        case .primary:
            return LinearGradient(
                colors: [.orange, .pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .secondary:
            return LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Disabled State Modifier

private struct DisabledStateModifier: ViewModifier {
    let isDisabled: Bool

    func body(content: Content) -> some View {
        content
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
    }
}

extension View {
    func disabledState(_ isDisabled: Bool) -> some View {
        modifier(DisabledStateModifier(isDisabled: isDisabled))
    }
}

// MARK: - Card Modifier

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
        .font(.headline)
        .foregroundStyle(.white)
}

func headerChip(title: String, color: Color) -> some View {
    Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.24))
        .clipShape(Capsule())
}

func actionButton(title: String, style: ActionButtonStyle, isDisabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(style.background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .disabledState(isDisabled)
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
    case .lobby: return .blue
    case .starting: return .purple
    case .collectingActions: return .green
    case .resolvingTurn: return .orange
    case .finished: return .gray
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

// MARK: - Colors

extension Color {
    static let statusBarBackground = Color(red: 0.12, green: 0.1, blue: 0.16)
}

// MARK: - Background Gradient

let appBackgroundGradient = LinearGradient(
    colors: [
        Color(red: 0.09, green: 0.08, blue: 0.14),
        Color(red: 0.14, green: 0.09, blue: 0.18),
        Color(red: 0.08, green: 0.1, blue: 0.16)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// MARK: - Reusable Input Components

struct GameTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            TextField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(12)
        }
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GameSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            SecureField("", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .padding(12)
        }
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GameTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 16)
            }

            TextField("", text: $text, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .foregroundStyle(.white)
                .lineLimit(2...7)
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
                .frame(minHeight: minHeight)
        }
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
