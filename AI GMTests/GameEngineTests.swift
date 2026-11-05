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

    func testRoundPromptListsPlayersWithoutAction() {
        let hero = Player(id: "p1", name: "勇者阿明", strength: 2, dexterity: 2, intelligence: 2, hp: 20)
        let mage = Player(id: "p2", name: "魔法師小花", strength: 2, dexterity: 2, intelligence: 2, hp: 20)
        let actions = [
            CampaignAction(id: "p1", playerId: "p1", playerName: "勇者阿明", text: "我拔出劍攻擊", isConfirmed: true),
        ]

        let prompt = engine.makeRoundPrompt(messages: [], players: [hero, mage], actions: actions)

        XCTAssertTrue(prompt.contains("本回合沒有行動的玩家：魔法師小花"), "沒確認的玩家應該告訴 AI")
        XCTAssertFalse(prompt.contains("沒有行動的玩家：勇者阿明"), "有行動的玩家不該被列為沒有行動")
    }

    func testRoundPromptOmitsIdleSectionWhenEveryoneActed() {
        let hero = Player(id: "p1", name: "勇者阿明", strength: 2, dexterity: 2, intelligence: 2, hp: 20)
        let actions = [
            CampaignAction(id: "p1", playerId: "p1", playerName: "勇者阿明", text: "我拔出劍攻擊", isConfirmed: true),
        ]

        let prompt = engine.makeRoundPrompt(messages: [], players: [hero], actions: actions)

        XCTAssertFalse(prompt.contains("沒有行動的玩家"), "全員都行動時不該出現這段")
    }

    func testRoundPromptGivesRollTotalForEachStat() {
        let hero = Player(id: "p1", name: "勇者阿明", strength: 5, dexterity: 3, intelligence: 1, hp: 20)
        let actions = [
            CampaignAction(id: "p1", playerId: "p1", playerName: "勇者阿明", text: "我拔出劍攻擊", isConfirmed: true),
        ]

        let prompt = engine.makeRoundPrompt(messages: [], players: [hero], actions: actions, rolls: ["p1": 14])

        XCTAssertTrue(prompt.contains("擲出 14：STR 19、DEX 17、INT 15"), "AI 應該拿到算好的數字，不用自己加")
    }

    func testRoundPromptOnlyListsRollsOfPlayersWhoActed() {
        let hero = Player(id: "p1", name: "勇者阿明", strength: 2, dexterity: 2, intelligence: 2, hp: 20)
        let mage = Player(id: "p2", name: "魔法師小花", strength: 2, dexterity: 2, intelligence: 2, hp: 20)
        let actions = [
            CampaignAction(id: "p1", playerId: "p1", playerName: "勇者阿明", text: "我拔出劍攻擊", isConfirmed: true),
        ]

        let prompt = engine.makeRoundPrompt(messages: [], players: [hero, mage], actions: actions, rolls: ["p1": 14])

        XCTAssertFalse(prompt.contains("魔法師小花 擲出"))
    }

    func testRoundPromptMarksDownedPlayers() {
        let hero = Player(id: "p1", name: "勇者阿明", strength: 2, dexterity: 2, intelligence: 2, hp: 0, maxHP: 20)
        let mage = Player(id: "p2", name: "魔法師小花", strength: 2, dexterity: 2, intelligence: 2, hp: 5, maxHP: 20)

        let prompt = engine.makeRoundPrompt(messages: [], players: [hero, mage], actions: [])

        XCTAssertTrue(prompt.contains("勇者阿明 HP 0/20（已倒下）"))
        XCTAssertFalse(prompt.contains("魔法師小花 HP 5/20（已倒下）"))
    }

    func testRoundPromptIdentifiesPlayersByCodeInListOrder() {
        let hero = Player(id: "p1", name: "勇者阿明", strength: 2, dexterity: 2, intelligence: 2, hp: 20)
        let mage = Player(id: "p2", name: "魔法師小花", strength: 2, dexterity: 2, intelligence: 2, hp: 20)
        let actions = [
            CampaignAction(id: "p2", playerId: "p2", playerName: "魔法師小花", text: "施放火球", isConfirmed: true),
        ]

        let prompt = engine.makeRoundPrompt(messages: [], players: [hero, mage], actions: actions, rolls: ["p2": 9])

        XCTAssertTrue(prompt.contains("P1 勇者阿明 HP"))
        XCTAssertTrue(prompt.contains("P2 魔法師小花 HP"))
        XCTAssertTrue(prompt.contains("P2 魔法師小花：施放火球"), "行動要用同一個代號，不能跟著行動清單重新編號")
        XCTAssertTrue(prompt.contains("P2 魔法師小花 擲出 9"), "擲骰要用同一個代號")
    }

    func testEndingPromptContainsHistoryAndPlayers() {
        let hero = Player(id: "p1", name: "勇者阿明", strength: 2, dexterity: 2, intelligence: 2, hp: 0, maxHP: 20)
        let messages = [
            CampaignMessage(id: "m1", kind: .narration, text: "巨龍噴出烈焰。", roundNumber: 3),
        ]

        let prompt = engine.makeEndingPrompt(messages: messages, players: [hero])

        XCTAssertTrue(prompt.contains("巨龍噴出烈焰。"), "結局要接得上目前的劇情")
        XCTAssertTrue(prompt.contains("勇者阿明"))
        XCTAssertTrue(prompt.contains("narration"))
    }
}
