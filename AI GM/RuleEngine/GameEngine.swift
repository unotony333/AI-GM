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
    private let aiService = AIService()
    
    private let successThreshold = 10
    
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
        
        let prompt = """
        你是一個TRPG GM。
        
        玩家：\(player.name)
        行動：\(input)
        
        \(rollInfo)
        結果：\(resultText)
        
        請用JSON回應：
        {
          "narration": "描述故事"
        }
        """
        
        do {
            let aiResponse = try await aiService.sendMessage(prompt: prompt)
            return aiResponse.narration
        } catch {
            return generateFallbackNarration(input: input, playerName: player.name, resultText: resultText)
        }
    }
    
    private func generateFallbackNarration(input: String, playerName: String, resultText: String) -> String {
        return "。\(playerName)嘗試「\(input)」，結果\(resultText)。系統暫時無法產生完整敘述。"
    }
    
    // MARK: - AI Decision
    
    func askAIDecision(action: String) async -> AIDecision? {
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
            let raw = try await aiService.sendRawJSON(prompt: prompt)
            guard let data = raw.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(AIDecision.self, from: data)
        } catch {
            return nil
        }
    }
}
