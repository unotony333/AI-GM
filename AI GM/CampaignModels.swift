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
    case finished
}

enum RoundStatus: String, Codable {
    case collecting
    case ready
    case resolving
    case resolved
}

enum CampaignMessageKind: String, Codable {
    case opening
    case system
    case narration
    case player
}

struct CampaignRoom: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let hostId: String
    let phase: CampaignPhase
    let provider: String
    let model: String
    let currentRoundId: String?
}

struct CampaignRound: Identifiable, Codable, Equatable {
    let id: String
    let number: Int
    let status: RoundStatus
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
}
