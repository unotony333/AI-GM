//
//  CampaignModels.swift
//  AI GM
//
//  Created by tony on 2026/3/31.
//

import Foundation

enum CampaignPhase: String, Codable {
    case lobby
    case starting
    case collectingActions
    case resolvingTurn
    /// 全員倒下，等房主向 AI 取得結局
    case ending
    case finished
}

enum RoundStatus: String, Codable {
    case collecting
}

enum CampaignMessageKind: String, Codable {
    case opening
    case system
    case narration
    case player
    case ending
}

struct CampaignAction: Identifiable, Codable, Equatable {
    let id: String
    let playerId: String
    let playerName: String
    let text: String
    let isConfirmed: Bool
}

struct CampaignMessage: Identifiable, Codable, Equatable {
    let id: String
    let kind: CampaignMessageKind
    let text: String
    let roundNumber: Int?
    var outcomes: [RoundOutcome] = []
}

enum PlayerStat: String, Codable, CaseIterable {
    case strength = "STR"
    case dexterity = "DEX"
    case intelligence = "INT"
}

/// App 擲的骰子加上 AI 選的屬性與難度
struct AbilityCheck: Codable, Equatable {
    let stat: PlayerStat
    let roll: Int
    let modifier: Int
    let difficulty: Int

    var total: Int { roll + modifier }
    var isSuccess: Bool { total >= difficulty }

    init(stat: PlayerStat, roll: Int, modifier: Int, difficulty: Int) {
        self.stat = stat
        self.roll = roll
        self.modifier = modifier
        self.difficulty = difficulty
    }

    init?(firestoreData data: [String: Any]) {
        guard let stat = (data["stat"] as? String).flatMap(PlayerStat.init(rawValue:)),
              let roll = data["roll"] as? Int,
              let modifier = data["modifier"] as? Int,
              let difficulty = data["difficulty"] as? Int else {
            return nil
        }
        self.init(stat: stat, roll: roll, modifier: modifier, difficulty: difficulty)
    }

    var firestoreData: [String: Any] {
        [
            "stat": stat.rawValue,
            "roll": roll,
            "modifier": modifier,
            "difficulty": difficulty
        ]
    }
}

/// 一位玩家這回合的結果，顯示在該回合的劇情下面
struct RoundOutcome: Identifiable, Codable, Equatable {
    let playerId: String
    let playerName: String
    let check: AbilityCheck?
    /// 實際變動的 HP，已扣除超過上下限的部分
    let hpChange: Int
    let reason: String?

    var id: String { playerId }

    init(playerId: String, playerName: String, check: AbilityCheck?, hpChange: Int, reason: String?) {
        self.playerId = playerId
        self.playerName = playerName
        self.check = check
        self.hpChange = hpChange
        self.reason = reason
    }

    init?(firestoreData data: [String: Any]) {
        guard let playerId = data["playerId"] as? String else { return nil }
        self.init(
            playerId: playerId,
            playerName: data["playerName"] as? String ?? "",
            check: (data["check"] as? [String: Any]).flatMap(AbilityCheck.init(firestoreData:)),
            hpChange: data["hpChange"] as? Int ?? 0,
            reason: data["reason"] as? String
        )
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "playerId": playerId,
            "playerName": playerName,
            "hpChange": hpChange
        ]
        if let check {
            data["check"] = check.firestoreData
        }
        if let reason {
            data["reason"] = reason
        }
        return data
    }

    var checkSummary: String? {
        guard let check else { return nil }
        return "\(playerName) 擲 \(check.roll) + \(check.stat.rawValue) \(check.modifier) = \(check.total)，難度 \(check.difficulty)"
    }

    var hpSummary: String? {
        guard hpChange != 0 else { return nil }
        let change = hpChange > 0 ? "+\(hpChange)" : "−\(-hpChange)"
        let reasonText = reason.map { "（\($0)）" } ?? ""
        return "\(playerName) \(change) HP\(reasonText)"
    }
}
