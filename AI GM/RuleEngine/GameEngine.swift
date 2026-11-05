//
//  GameEngine.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

/// 一回合結算完的結果，由 App 檢查過 AI 的回傳後算出
struct RoundResolution {
    let narration: String
    let outcomes: [RoundOutcome]
    /// 結算後每位玩家的 HP，以玩家 ID 為 key
    let updatedHP: [String: Int]
    let isPartyDown: Bool
}

final class GameEngine {
    private static let maxHPLossPerRound = 10
    private static let difficultyRange = 5...20

    private let rollD20: () -> Int

    init(rollD20: @escaping () -> Int = { Int.random(in: 1...20) }) {
        self.rollD20 = rollD20
    }

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
        actions: [CampaignAction],
        rolls: [String: Int] = [:]
    ) -> String {
        let messageSummary = summarize(messages)

        let playerSummary = players.enumerated().map { index, player in
            "\(Self.playerCode(at: index)) \(player.statSummary)"
        }.joined(separator: "\n")

        let actionSummary = actions.map { action in
            "\(playerLabel(for: action, in: players))：\(action.text)"
        }.joined(separator: "\n")

        let rollSummary = players.enumerated().compactMap { index, player -> String? in
            guard let roll = rolls[player.id] else { return nil }
            let totals = PlayerStat.allCases
                .map { "\($0.rawValue) \(roll + player.modifier(for: $0))" }
                .joined(separator: "、")
            return "\(Self.playerCode(at: index)) \(player.name) 擲出 \(roll)：\(totals)"
        }.joined(separator: "\n")
        let rollSection = rollSummary.isEmpty ? "" : "\n\n本回合擲骰（已加上屬性）：\n\(rollSummary)"

        // 房主可以不等所有人就結算，讓 AI 知道誰這回合沒有行動
        let idlePlayerNames = players
            .filter { player in !actions.contains { $0.playerId == player.id } }
            .map(\.name)
        let idleSummary = idlePlayerNames.isEmpty
            ? ""
            : "\n\n本回合沒有行動的玩家：\(idlePlayerNames.joined(separator: "、"))"

        return """
        請根據目前劇情與玩家行動結算本回合。

        規則：
        - 需要檢定的行動，選最相關的屬性（STR、DEX 或 INT），並依難易度決定 dc（\(Self.difficultyRange.lowerBound) 到 \(Self.difficultyRange.upperBound)）。玩家該屬性的擲骰數字大於或等於 dc 就成功，劇情要符合這個結果。
        - 不需要檢定的行動（例如交談），stat 和 dc 填 null。
        - hpChange 是這回合的 HP 變化：受傷用負數，回復用正數，沒變化填 0。一般傷害約 -2 到 -5，最多 -\(Self.maxHPLossPerRound)。這回合沒行動的人也可能受傷。
        - HP 歸零的玩家已倒下，但仍可能輸入行動，由你判斷能不能做、能做到什麼程度。
        - 其他玩家可以嘗試救回倒下的玩家，倒下的玩家也可以試著自己站起來，由你判斷是否可行；可行就用正數的 hpChange 回復。
        - 劇情裡用玩家的名字稱呼，不要用代號。

        玩家列表：
        \(playerSummary)

        先前訊息：
        \(messageSummary)

        本回合行動：
        \(actionSummary)\(rollSection)\(idleSummary)

        請用JSON回應，results 列出這回合有檢定或 HP 變化的玩家，player 填玩家代號：
        {
          "narration": "...",
          "results": [
            {"player": "P1", "stat": "STR", "dc": 12, "hpChange": -3, "reason": "被哥布林砍中"}
          ]
        }
        """
    }

    func makeEndingPrompt(messages: [CampaignMessage], players: [Player]) -> String {
        let playerSummary = players.map(\.statSummary).joined(separator: "\n")

        return """
        所有玩家都已倒下，這場冒險到此結束。請根據目前劇情，為這場冒險寫一段故事結尾。

        玩家列表：
        \(playerSummary)

        先前訊息：
        \(summarize(messages))

        請用JSON回應：
        {
          "narration": "..."
        }
        """
    }

    func rollDice(for actions: [CampaignAction]) -> [String: Int] {
        var rolls: [String: Int] = [:]
        for action in actions {
            rolls[action.playerId] = rollD20()
        }
        return rolls
    }

    /// AI 的回傳不一定可靠：只採用對得上玩家的結果，難度和 HP 變化都限制在規則範圍內
    func makeResolution(
        narration: String,
        results: [AIPlayerResult],
        players: [Player],
        rolls: [String: Int]
    ) -> RoundResolution {
        var updatedHP = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.hp) })
        var outcomes: [RoundOutcome] = []
        var resolvedPlayerIds = Set<String>()

        for result in results {
            guard let player = player(matching: result.player, in: players),
                  resolvedPlayerIds.insert(player.id).inserted else {
                continue
            }

            let newHP = min(max(player.hp + max(result.hpChange, -Self.maxHPLossPerRound), 0), player.maxHP)
            updatedHP[player.id] = newHP

            let check = makeCheck(from: result, player: player, roll: rolls[player.id])
            let hpChange = newHP - player.hp
            guard check != nil || hpChange != 0 else { continue }

            let reason = result.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            outcomes.append(RoundOutcome(
                playerId: player.id,
                playerName: player.name,
                check: check,
                hpChange: hpChange,
                reason: reason?.isEmpty == false ? reason : nil
            ))
        }

        return RoundResolution(
            narration: narration,
            outcomes: outcomes,
            updatedHP: updatedHP,
            isPartyDown: !players.isEmpty && updatedHP.values.allSatisfy { $0 == 0 }
        )
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
    ) async throws -> RoundResolution {
        let rolls = rollDice(for: actions)
        let prompt = makeRoundPrompt(
            messages: messages,
            players: players,
            actions: actions,
            rolls: rolls
        )
        let aiService = AIService(configuration: configuration)
        let response = try await aiService.sendMessage(messages: narrationMessages(
            userPrompt: prompt,
            systemPrompt: configuration.systemPrompt
        ))
        return makeResolution(
            narration: response.narration,
            results: response.results,
            players: players,
            rolls: rolls
        )
    }

    func generateEnding(
        messages: [CampaignMessage],
        players: [Player],
        configuration: AIHostConfiguration
    ) async throws -> String {
        let prompt = makeEndingPrompt(messages: messages, players: players)
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

    private func summarize(_ messages: [CampaignMessage]) -> String {
        messages.map { message in
            let roundText = message.roundNumber.map { "第\($0)回合" } ?? "無回合"
            return "[\(message.kind.rawValue)][\(roundText)] \(message.text)"
        }.joined(separator: "\n")
    }

    /// 給 AI 的玩家代號。玩家可能同名，ID 又太長，模型容易寫錯
    private static func playerCode(at index: Int) -> String {
        "P\(index + 1)"
    }

    private func playerLabel(for action: CampaignAction, in players: [Player]) -> String {
        guard let index = players.firstIndex(where: { $0.id == action.playerId }) else {
            return action.playerName
        }
        return "\(Self.playerCode(at: index)) \(action.playerName)"
    }

    /// 優先比對代號；有些模型會改寫成玩家名字，名字不重複時也接受
    private func player(matching reference: String, in players: [Player]) -> Player? {
        let reference = reference.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = players.indices.first(where: { Self.playerCode(at: $0).caseInsensitiveCompare(reference) == .orderedSame }) {
            return players[index]
        }

        let namedPlayers = players.filter { $0.name == reference }
        return namedPlayers.count == 1 ? namedPlayers.first : nil
    }

    private func makeCheck(from result: AIPlayerResult, player: Player, roll: Int?) -> AbilityCheck? {
        guard let roll,
              let difficulty = result.dc,
              let stat = result.stat.flatMap({ PlayerStat(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) }) else {
            return nil
        }

        return AbilityCheck(
            stat: stat,
            roll: roll,
            modifier: player.modifier(for: stat),
            difficulty: min(max(difficulty, Self.difficultyRange.lowerBound), Self.difficultyRange.upperBound)
        )
    }
}
