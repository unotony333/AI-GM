//
//  ContentView.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import SwiftUI

struct ContentView: View {

    @StateObject var campaign = CampaignService()
    let engine = GameEngine()

    @State private var playerName = ""
    @State private var campaignInput = ""
    @State private var input = ""
    @State private var isProcessing = false

    var isMyTurn: Bool {
        campaign.currentTurn == UserService.shared.userId
    }

    var body: some View {
        VStack {

            if campaign.campaignId == nil {
                // Lobby
                TextField("你的名字", text: $playerName)
                Button("建立房間") {
                    campaign.createCampaign(name: "Test", playerName: playerName)
                }

                TextField("房間ID", text: $campaignInput)
                Button("加入") {
                    campaign.joinCampaign(campaignId: campaignInput, playerName: playerName)
                }

            } else {
                Text("房間：\(campaign.campaignId!)")
                Text(isMyTurn ? "輪到你" : "等待中")

                ScrollView {
                    ForEach(campaign.messages, id: \.self) {
                        Text($0)
                    }
                }

                TextField("輸入行動", text: $input)
                    .disabled(!isMyTurn || isProcessing)

                Button("送出") {
                    send()
                }
                .disabled(!isMyTurn || isProcessing)
            }
        }
        .padding()
    }

    func send() {
        guard isMyTurn else { return }

        let action = input
        input = ""

        campaign.sendMessage("玩家：\(action)")

        Task {
            let player = campaign.players.first { $0.id == campaign.currentTurn }

            if let player {
                let result = await engine.processAction(action, player: player)
                campaign.sendMessage("GM：\(result)")
                campaign.advanceTurn()
            }

            isProcessing = false
        }
    }
}

#Preview {
    ContentView()
}
