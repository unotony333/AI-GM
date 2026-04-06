//
//  GameEngine.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

final class GameEngine {
    func makeOpeningPrompt(players: [Player]) -> String {
        let playerSummary = players.map(\.statSummary).joined(separator: "\n")

        return """
        請為以下角色生成故事開場。

        玩家列表：
        \(playerSummary)

        請用JSON回應：
        {
          "narration": "..."
        }
        """
    }

    func makeRoundPrompt(
        messages: [CampaignMessage],
        players: [Player],
        actions: [CampaignAction]
    ) -> String {
        let messageSummary = messages.map { message in
            let roundText = message.roundNumber.map { "第\($0)回合" } ?? "無回合"
            return "[\(message.kind.rawValue)][\(roundText)] \(message.text)"
        }.joined(separator: "\n")

        let playerSummary = players.map(\.statSummary).joined(separator: "\n")
        let actionSummary = actions.map { action in
            "\(action.playerName)：\(action.text)"
        }.joined(separator: "\n")

        return """
        請根據目前劇情與玩家行動結算本回合。

        玩家列表：
        \(playerSummary)

        先前訊息：
        \(messageSummary)

        本回合行動：
        \(actionSummary)

        請用JSON回應：
        {
          "narration": "..."
        }
        """
    }

    func generateOpeningNarration(players: [Player], configuration: AIHostConfiguration) async throws -> String {
        let prompt = makeOpeningPrompt(players: players)
        let aiService = AIService(configuration: configuration)
        return try await aiService.sendMessage(messages: narrationMessages(
            userPrompt: prompt,
            systemPrompt: configuration.systemPrompt
        )).narration
    }

    func resolveRound(
        messages: [CampaignMessage],
        players: [Player],
        actions: [CampaignAction],
        configuration: AIHostConfiguration
    ) async throws -> String {
        let prompt = makeRoundPrompt(
            messages: messages,
            players: players,
            actions: actions
        )
        let aiService = AIService(configuration: configuration)
        return try await aiService.sendMessage(messages: narrationMessages(
            userPrompt: prompt,
            systemPrompt: configuration.systemPrompt
        )).narration
    }

    private func narrationMessages(userPrompt: String, systemPrompt: String) -> [AIService.Message] {
        [
            AIService.Message(role: .system, content: "\(systemPrompt)\n只輸出JSON。"),
            AIService.Message(role: .user, content: userPrompt)
        ]
    }
}
