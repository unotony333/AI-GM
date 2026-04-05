//
//  AISettingsSheet.swift
//  AI GM
//
//  Extracted from ContentView.swift
//

import SwiftUI

struct AISettingsSheet: View {
    @Binding var draft: AISettingsDraft
    let hasPendingChanges: Bool
    let onCommit: () -> Void
    let onDismiss: () -> Void

    @State private var isShowingDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.07, blue: 0.12),
                        Color(red: 0.12, green: 0.09, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("AI 供應商")

                            Picker("AI 供應商", selection: providerPresetBinding) {
                                ForEach(AIProviderPreset.allCases) { preset in
                                    Text(preset.provider).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(draft.providerPreset.description)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("連線設定")

                            HStack(spacing: 8) {
                                headerChip(title: draft.providerPreset.provider, color: .pink)
                                headerChip(title: formatLabel(draft.apiFormat), color: .blue)
                            }

                            GameTextField(placeholder: "Base URL，例如 https://api.openai.com/v1", text: $draft.baseURL)
                            GameTextField(placeholder: "Model，例如 gpt-4o-mini / llama3.1", text: $draft.model)
                            GameSecureField(placeholder: "API Key", text: $draft.apiKey)
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("主持風格")
                            GameTextEditor(placeholder: "System Prompt", text: $draft.systemPrompt, minHeight: 180)
                        }
                        .cardStyle()
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        requestDismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }

                ToolbarItem(placement: .principal) {
                    Text("AI 設定")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onCommit()
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasPendingChanges)
        .alert("放棄這次 AI 設定變更？", isPresented: $isShowingDiscardConfirmation) {
            Button("繼續編輯", role: .cancel) { }
            Button("放棄變更", role: .destructive) {
                onDismiss()
            }
        } message: {
            Text("你在 AI 設定中的修改尚未套用。")
        }
    }

    private var providerPresetBinding: Binding<AIProviderPreset> {
        Binding(
            get: { draft.providerPreset },
            set: { preset in
                draft.applyPreset(preset)
            }
        )
    }

    private func requestDismiss() {
        if hasPendingChanges {
            isShowingDiscardConfirmation = true
        } else {
            onDismiss()
        }
    }
}
