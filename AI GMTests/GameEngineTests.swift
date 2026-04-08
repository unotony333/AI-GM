//
//  GameEngineTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class GameEngineTests: XCTestCase {

    private let engine = GameEngine()

    private func makePlayer(name: String, hp: Int = 20, str: Int = 2, dex: Int = 2, int: Int = 2) -> Player {
        Player(id: UUID().uuidString, name: name, strength: str, dexterity: dex, intelligence: int, hp: hp)
    }

    func testOpeningPromptContainsAllPlayers() {
        let players = [
            makePlayer(name: "勇者阿明", str: 5),
            makePlayer(name: "魔法師小花", int: 5),
        ]

        let prompt = engine.makeOpeningPrompt(players: players)

        XCTAssertTrue(prompt.contains("勇者阿明"), "Prompt should contain player name '勇者阿明'")
        XCTAssertTrue(prompt.contains("魔法師小花"), "Prompt should contain player name '魔法師小花'")
        XCTAssertTrue(prompt.contains("STR 5"), "Prompt should contain '勇者阿明' STR stat")
        XCTAssertTrue(prompt.contains("INT 5"), "Prompt should contain '魔法師小花' INT stat")
        XCTAssertTrue(prompt.contains("narration"), "Prompt should request JSON narration format")
    }

    func testRoundPromptContainsActionsAndMessages() {
        let players = [
            makePlayer(name: "勇者阿明"),
        ]

        let messages = [
            CampaignMessage(id: "m1", kind: .opening, text: "冒險開始了。", roundNumber: nil),
            CampaignMessage(id: "m2", kind: .narration, text: "你來到了森林。", roundNumber: 1),
        ]

        let actions = [
            CampaignAction(id: "a1", playerId: "p1", playerName: "勇者阿明", text: "我拔出劍攻擊", isConfirmed: true),
        ]

        let prompt = engine.makeRoundPrompt(messages: messages, players: players, actions: actions)

        XCTAssertTrue(prompt.contains("冒險開始了。"), "Prompt should contain opening message")
        XCTAssertTrue(prompt.contains("你來到了森林。"), "Prompt should contain previous narration")
        XCTAssertTrue(prompt.contains("勇者阿明"), "Prompt should contain player name")
        XCTAssertTrue(prompt.contains("我拔出劍攻擊"), "Prompt should contain player action")
        XCTAssertTrue(prompt.contains("narration"), "Prompt should request JSON narration format")
    }
}
