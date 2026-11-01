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
                FeltBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("AI 供應商")

                            Picker("AI 供應商", selection: providerPresetBinding) {
                                ForEach(AIProviderPreset.allCases) { preset in
                                    Text(preset.provider).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Palette.vellum)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.feltSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 1)
                            )

                            Text(draft.providerPreset.description)
                                .font(.caption)
                                .foregroundStyle(Palette.sage)
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                sectionTitle("連線設定")
                                Spacer()
                                headerChip(title: formatLabel(draft.apiFormat), color: Palette.sage)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Base URL")
                                GameTextField(placeholder: "例如 https://api.openai.com/v1", text: $draft.baseURL)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("Model")
                                GameTextField(placeholder: "例如 gpt-4o-mini / llama3.1", text: $draft.model)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                fieldLabel("API Key")
                                GameSecureField(placeholder: "只存在這台裝置的 Keychain", text: $draft.apiKey)
                            }
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 10) {
                            sectionTitle("主持風格")
                            Text("告訴 GM 要用什麼語氣、世界觀與規則主持。")
                                .font(.caption)
                                .foregroundStyle(Palette.sage)
                            GameTextEditor(placeholder: "System Prompt", text: $draft.systemPrompt, minHeight: 180)
                        }
                        .cardStyle()
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        requestDismiss()
                    }
                    .foregroundStyle(Palette.sage)
                }

                ToolbarItem(placement: .principal) {
                    Text("AI 設定")
                        .serifFont(.quote)
                        .foregroundStyle(Palette.vellum)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onCommit()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
