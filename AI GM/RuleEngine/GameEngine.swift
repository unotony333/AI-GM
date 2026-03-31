//
//  GameEngine.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

enum CheckType: String {
    case strength
    case dexterity
    case intelligence
}

class GameEngine {
    private let parser = ActionParser()
    private let defaultConfiguration: AIHostConfiguration?
    
    private let successThreshold = 10

    init(configuration: AIHostConfiguration? = nil) {
        self.defaultConfiguration = configuration
    }
    
    func performCheck(player: Player, type: CheckType) -> (roll: Int, total: Int, success: Bool) {
        let roll = Int.random(in: 1...20)
        
        let modifier: Int
        switch type {
        case .strength: modifier = player.strength
        case .dexterity: modifier = player.dexterity
        case .intelligence: modifier = player.intelligence
        }
        
        let total = roll + modifier
        let success = total >= successThreshold
        
        return (roll, total, success)
    }

    func makeOpeningPrompt(players: [Player], systemPrompt: String) -> String {
        _ = systemPrompt
        let playerSummary = players.map(\.statSummary).joined(separator: "\n")

        return """
        你是一個TRPG GM，請為以下角色生成故事開場。

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
        actions: [CampaignAction],
        systemPrompt: String
    ) -> String {
        _ = systemPrompt
        let messageSummary = messages.map { message in
            let roundText = message.roundNumber.map { "第\($0)回合" } ?? "無回合"
            return "[\(message.kind.rawValue)][\(roundText)] \(message.text)"
        }.joined(separator: "\n")

        let playerSummary = players.map(\.statSummary).joined(separator: "\n")
        let actionSummary = actions.map { action in
            "\(action.playerName)：\(action.text)"
        }.joined(separator: "\n")

        return """
        你是一個TRPG GM，請根據目前劇情與玩家行動結算本回合。

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
        let prompt = makeOpeningPrompt(players: players, systemPrompt: configuration.systemPrompt)
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
            actions: actions,
            systemPrompt: configuration.systemPrompt
        )
        let aiService = AIService(configuration: configuration)
        return try await aiService.sendMessage(messages: narrationMessages(
            userPrompt: prompt,
            systemPrompt: configuration.systemPrompt
        )).narration
    }

    // Temporary compatibility helper for pre-Task-3/4 callers that still use GameEngine().processAction(_:player:).
    // When no configuration is injected, this path stays offline and falls back locally.
    func processAction(_ input: String, player: Player) async -> String {
        let parsed = parser.parse(input)
        var checkType = parsed.check
        
        // fallback → AI 判斷
        if checkType == nil {
            if let decision = await askAIDecision(action: input),
               decision.requires_roll,
               let typeString = decision.check_type {
                checkType = CheckType(rawValue: typeString)
            }
        }
        
        var rollInfo = ""
        var resultText = ""
        
        if let checkType {
            let result = performCheck(player: player, type: checkType)
            
            rollInfo = """
            檢定：\(checkType.rawValue)
            骰子：\(result.roll)
            總值：\(result.total)
            """
            
            resultText = result.success ? "成功" : "失敗"
        } else {
            resultText = "無需檢定"
        }
        
        let action = CampaignAction(
            id: UUID().uuidString,
            playerId: player.id,
            playerName: player.name,
            text: input,
            isConfirmed: true
        )
        let systemMessage = CampaignMessage(
            id: UUID().uuidString,
            kind: .system,
            text: "\(rollInfo)\n結果：\(resultText)",
            roundNumber: nil
        )

        guard let configuration = defaultConfiguration else {
            return generateFallbackNarration(input: input, playerName: player.name, resultText: resultText)
        }
        
        do {
            return try await resolveRound(
                messages: [systemMessage],
                players: [player],
                actions: [action],
                configuration: configuration
            )
        } catch {
            return generateFallbackNarration(input: input, playerName: player.name, resultText: resultText)
        }
    }
    
    private func generateFallbackNarration(input: String, playerName: String, resultText: String) -> String {
        return "。\(playerName)嘗試「\(input)」，結果\(resultText)。系統暫時無法產生完整敘述。"
    }
    
    // MARK: - AI Decision
    
    // Temporary compatibility helper used by the legacy processAction path until newer campaign flows take over.
    // With no injected configuration, this remains offline and returns nil instead of attempting a request.
    func askAIDecision(action: String) async -> AIDecision? {
        guard let configuration = defaultConfiguration else {
            return nil
        }

        let prompt = """
        判斷是否需要檢定。
        
        回傳JSON：
        {
          "requires_roll": true 或 false,
          "check_type": "strength/dexterity/intelligence 或 null"
        }
        
        行動：\(action)
        """
        
        do {
            let aiService = AIService(configuration: configuration)
            let raw = try await aiService.sendRawJSON(messages: [
                AIService.Message(role: .system, content: "只輸出JSON"),
                AIService.Message(role: .user, content: prompt)
            ])
            guard let data = raw.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(AIDecision.self, from: data)
        } catch {
            return nil
        }
    }

    private func narrationMessages(userPrompt: String, systemPrompt: String) -> [AIService.Message] {
        [
            AIService.Message(role: .system, content: "\(systemPrompt)\n只輸出JSON。"),
            AIService.Message(role: .user, content: userPrompt)
        ]
    }
}
