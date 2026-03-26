//
//  ContentView.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        NavigationStack {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.15)
                    .ignoresSafeArea()

                if campaign.campaignId == nil {
                    lobbyView
                } else {
                    gameView
                }
            }
        }
    }

    private var lobbyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "dice.3d.fill")
                .font(.system(size: 80))
                .foregroundStyle(.purple, .pink)
            
            Text("AI GM")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            
            Text("文字冒險遊戲")
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            Spacer().frame(height: 40)
            
            VStack(spacing: 16) {
                GameTextField(placeholder: "你的名字", text: $playerName)
                    .padding(.horizontal, 40)
                
                Button {
                    campaign.createCampaign(name: "Test", playerName: playerName)
                } label: {
                    Text("建立房間")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                
                Text("或")
                    .foregroundStyle(.gray)
                
                HStack(spacing: 12) {
                    GameTextField(placeholder: "房間ID", text: $campaignInput)
                        .frame(width: 200)
                    
                    Button {
                        campaign.joinCampaign(campaignId: campaignInput, playerName: playerName)
                    } label: {
                        Text("加入")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }

    private var gameView: some View {
        VStack(spacing: 0) {
            headerBar
            
            messageList
            
            inputBar
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("房間")
                    .font(.caption)
                    .foregroundStyle(.gray)
                HStack(spacing: 8) {
                    Text(campaign.campaignId!)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = campaign.campaignId
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(campaign.campaignId!, forType: .string)
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(isMyTurn ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(isMyTurn ? "輪到你" : "等待中")
                    .font(.subheadline)
                    .foregroundStyle(isMyTurn ? .green : .orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.2))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<campaign.messages.count, id: \.self) { index in
                        messageBubble(campaign.messages[index], isPlayer: index % 2 == 0)
                            .id(index)
                    }
                }
                .padding()
            }
            .onChange(of: campaign.messages.count) { _, _ in
                if let lastIndex = campaign.messages.indices.last {
                    withAnimation {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: String, isPlayer: Bool) -> some View {
        HStack {
            if isPlayer { Spacer() }
            
            Text(message)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(isPlayer ? Color.purple.opacity(0.8) : Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            if !isPlayer { Spacer() }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            GameTextField(placeholder: "輸入行動", text: $input)
                .disabled(!isMyTurn || isProcessing)
                .opacity(isMyTurn ? 1 : 0.5)
            
            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
            .disabled(!isMyTurn || isProcessing)
            .opacity(isMyTurn && !isProcessing ? 1 : 0.5)
        }
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.2))
    }

    func send() {
        guard isMyTurn, !input.isEmpty else { return }

        let action = input
        input = ""
        isProcessing = true

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
                .foregroundStyle(.white)
                .padding(12)
        }
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ContentView()
}
