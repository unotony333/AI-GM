//
//  ContentView.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var campaign = CampaignService()
    @StateObject private var aiSettings = AISettingsViewModel()
    @StateObject private var lobbyVM = LobbyViewModel()

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { campaign.localErrorMessage != nil },
            set: { if !$0 { campaign.localErrorMessage = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                if campaign.campaignId == nil {
                    LobbyView(
                        vm: lobbyVM,
                        campaign: campaign,
                        aiSettings: aiSettings
                    )
                } else {
                    GameView(
                        campaign: campaign,
                        aiSettings: aiSettings
                    )
                }
            }
            .alert("錯誤", isPresented: showErrorAlert) {
                Button("好") {
                    campaign.localErrorMessage = nil
                }
            } message: {
                Text(campaign.localErrorMessage ?? "")
            }
            .onChange(of: campaign.campaignId) { _, newId in
                if let newId {
                    lobbyVM.campaignInput = newId
                }
            }
            .onAppear {
                aiSettings.restoreLastUsedIfNeeded { error in
                    campaign.localErrorMessage = error
                }
            }
            .sheet(isPresented: $aiSettings.isPresented) {
                AISettingsSheet(
                    draft: $aiSettings.draft,
                    hasPendingChanges: aiSettings.hasPendingChanges,
                    onCommit: { aiSettings.commit(campaign: campaign) },
                    onDismiss: { aiSettings.dismiss() }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
