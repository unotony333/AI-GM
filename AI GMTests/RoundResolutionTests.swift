//
//  RoundResolutionTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class RoundResolutionTests: XCTestCase {

    private let engine = GameEngine()

    private func makePlayer(id: String = "p1", name: String = "Jack", hp: Int = 20, str: Int = 2, dex: Int = 2, int: Int = 2) -> Player {
        Player(id: id, name: name, strength: str, dexterity: dex, intelligence: int, hp: hp, maxHP: 20)
    }

    private func makeAction(playerId: String) -> CampaignAction {
        CampaignAction(id: playerId, playerId: playerId, playerName: playerId, text: "行動", isConfirmed: true)
    }

    private func makeResult(_ player: String = "P1", stat: String? = nil, dc: Int? = nil, hpChange: Int = 0, reason: String? = nil) -> AIPlayerResult {
        AIPlayerResult(player: player, stat: stat, dc: dc, hpChange: hpChange, reason: reason)
    }

    private func resolve(_ results: [AIPlayerResult], players: [Player], rolls: [String: Int] = [:]) -> RoundResolution {
        engine.makeResolution(narration: "劇情", results: results, players: players, rolls: rolls)
    }

    // MARK: - Dice

    func testEachPlayerWithActionRollsOnce() {
        var nextRolls = [14, 3].makeIterator()
        let engine = GameEngine(rollD20: { nextRolls.next()! })

        let rolls = engine.rollDice(for: [makeAction(playerId: "p1"), makeAction(playerId: "p2")])

        XCTAssertEqual(rolls, ["p1": 14, "p2": 3])
    }

    func testDefaultDiceStayWithinD20() {
        let actions = (0..<500).map { makeAction(playerId: "p\($0)") }

        let rolls = Array(engine.rollDice(for: actions).values)

        XCTAssertTrue(rolls.allSatisfy { (1...20).contains($0) }, "d20 只會擲出 1 到 20")
        XCTAssertGreaterThan(Set(rolls).count, 1, "骰子應該是隨機的")
    }

    // MARK: - Checks

    func testCheckSucceedsWhenTotalMeetsDifficulty() throws {
        let resolution = resolve([makeResult(stat: "STR", dc: 12)], players: [makePlayer()], rolls: ["p1": 10])

        let check = try XCTUnwrap(resolution.outcomes.first?.check)
        XCTAssertEqual(check.total, 12)
        XCTAssertTrue(check.isSuccess, "10 + STR 2 = 12，剛好達到難度就算成功")
    }

    func testCheckFailsBelowDifficulty() throws {
        let resolution = resolve([makeResult(stat: "STR", dc: 13)], players: [makePlayer()], rolls: ["p1": 10])

        XCTAssertFalse(try XCTUnwrap(resolution.outcomes.first?.check).isSuccess)
    }

    func testCheckUsesModifierOfChosenStat() throws {
        let player = makePlayer(str: 1, dex: 5, int: 3)

        let resolution = resolve([makeResult(stat: "DEX", dc: 10)], players: [player], rolls: ["p1": 7])

        let check = try XCTUnwrap(resolution.outcomes.first?.check)
        XCTAssertEqual(check.stat, .dexterity)
        XCTAssertEqual(check.total, 12, "應該加 DEX 5，不是其他屬性")
    }

    func testStatNameIgnoresCase() {
        let resolution = resolve([makeResult(stat: "int", dc: 10)], players: [makePlayer()], rolls: ["p1": 7])

        XCTAssertEqual(resolution.outcomes.first?.check?.stat, .intelligence)
    }

    func testDifficultyIsKeptWithinRange() {
        let tooHard = resolve([makeResult(stat: "STR", dc: 99)], players: [makePlayer()], rolls: ["p1": 18])
        let tooEasy = resolve([makeResult(stat: "STR", dc: -3)], players: [makePlayer()], rolls: ["p1": 1])

        XCTAssertEqual(tooHard.outcomes.first?.check?.difficulty, 20)
        XCTAssertEqual(tooHard.outcomes.first?.check?.isSuccess, true, "18 + 2 達到被限制後的難度 20")
        XCTAssertEqual(tooEasy.outcomes.first?.check?.difficulty, 5)
        XCTAssertEqual(tooEasy.outcomes.first?.check?.isSuccess, false, "1 + 2 沒達到被限制後的難度 5")
    }

    func testResultWithoutUsableCheckHasNoCheck() {
        let cases: [(stat: String?, dc: Int?)] = [(nil, nil), ("LUCK", 10), ("STR", nil), (nil, 10)]

        for (stat, dc) in cases {
            let resolution = resolve(
                [makeResult(stat: stat, dc: dc, hpChange: -1)],
                players: [makePlayer()],
                rolls: ["p1": 10]
            )

            XCTAssertNil(resolution.outcomes.first?.check, "stat: \(stat ?? "nil"), dc: \(dc.map(String.init) ?? "nil")")
            XCTAssertEqual(resolution.outcomes.first?.hpChange, -1, "檢定不成立時 HP 變化仍然有效")
        }
    }

    func testIdlePlayerHasNoCheckButCanBeHurt() {
        let resolution = resolve([makeResult(stat: "STR", dc: 10, hpChange: -4)], players: [makePlayer()], rolls: [:])

        XCTAssertNil(resolution.outcomes.first?.check, "沒行動的玩家沒有擲骰，不能有檢定")
        XCTAssertEqual(resolution.updatedHP["p1"], 16)
    }

    // MARK: - HP

    func testDamageIsLimitedPerRound() {
        let resolution = resolve([makeResult(hpChange: -50)], players: [makePlayer()])

        XCTAssertEqual(resolution.updatedHP["p1"], 10, "一回合最多扣 10")
        XCTAssertEqual(resolution.outcomes.first?.hpChange, -10)
    }

    func testHPStopsAtZeroAndReportsActualChange() {
        let resolution = resolve([makeResult(hpChange: -5)], players: [makePlayer(hp: 3)])

        XCTAssertEqual(resolution.updatedHP["p1"], 0)
        XCTAssertEqual(resolution.outcomes.first?.hpChange, -3, "畫面要顯示實際扣掉的 HP")
    }

    func testHealingStopsAtMaxHPAndReportsActualChange() {
        let resolution = resolve([makeResult(hpChange: 10)], players: [makePlayer(hp: 18)])

        XCTAssertEqual(resolution.updatedHP["p1"], 20)
        XCTAssertEqual(resolution.outcomes.first?.hpChange, 2)
    }

    func testDownedPlayerCanBeRevived() {
        let resolution = resolve([makeResult(hpChange: 5)], players: [makePlayer(hp: 0)])

        XCTAssertEqual(resolution.updatedHP["p1"], 5)
    }

    func testDownedPlayerTakingDamageProducesNoOutcome() {
        let resolution = resolve([makeResult(hpChange: -5)], players: [makePlayer(hp: 0)])

        XCTAssertEqual(resolution.updatedHP["p1"], 0)
        XCTAssertTrue(resolution.outcomes.isEmpty, "HP 沒變也沒檢定時，不該顯示任何結果")
    }

    func testPlayersWithoutResultKeepTheirHP() {
        let players = [makePlayer(id: "p1", hp: 7), makePlayer(id: "p2", hp: 12)]

        let resolution = resolve([makeResult("P1", hpChange: -1)], players: players)

        XCTAssertEqual(resolution.updatedHP, ["p1": 6, "p2": 12])
    }

    // MARK: - Matching players

    func testPlayersAreMatchedByCodeInListOrder() {
        let players = [makePlayer(id: "p1", name: "Jack"), makePlayer(id: "p2", name: "Mia")]

        let resolution = resolve([makeResult("P2", hpChange: -2)], players: players)

        XCTAssertEqual(resolution.updatedHP, ["p1": 20, "p2": 18])
        XCTAssertEqual(resolution.outcomes.first?.playerName, "Mia")
    }

    func testPlayerCanBeMatchedByNameWhenModelIgnoresCode() {
        let players = [makePlayer(id: "p1", name: "Jack"), makePlayer(id: "p2", name: "Mia")]

        let resolution = resolve([makeResult("Mia", hpChange: -2)], players: players)

        XCTAssertEqual(resolution.updatedHP["p2"], 18)
    }

    func testAmbiguousNameIsIgnored() {
        let players = [makePlayer(id: "p1", name: "Jack"), makePlayer(id: "p2", name: "Jack")]

        let resolution = resolve([makeResult("Jack", hpChange: -2)], players: players)

        XCTAssertEqual(resolution.updatedHP, ["p1": 20, "p2": 20], "同名時不知道是誰，不該猜")
    }

    func testUnknownPlayerIsIgnored() {
        let resolution = resolve([makeResult("哥布林", hpChange: -5)], players: [makePlayer()])

        XCTAssertEqual(resolution.updatedHP, ["p1": 20])
        XCTAssertTrue(resolution.outcomes.isEmpty)
    }

    func testOnlyFirstResultForPlayerCounts() {
        let resolution = resolve(
            [makeResult(hpChange: -2), makeResult(hpChange: -3)],
            players: [makePlayer()]
        )

        XCTAssertEqual(resolution.updatedHP["p1"], 18)
        XCTAssertEqual(resolution.outcomes.count, 1)
    }

    // MARK: - Game over

    func testPartyIsDownWhenEveryoneReachesZero() {
        let players = [makePlayer(id: "p1", hp: 3), makePlayer(id: "p2", hp: 0)]

        let resolution = resolve([makeResult("P1", hpChange: -3)], players: players)

        XCTAssertTrue(resolution.isPartyDown)
    }

    func testPartyIsNotDownWhileAnyoneHasHP() {
        let players = [makePlayer(id: "p1", hp: 3), makePlayer(id: "p2", hp: 1)]

        let resolution = resolve([makeResult("P1", hpChange: -3)], players: players)

        XCTAssertFalse(resolution.isPartyDown)
    }

    func testRevivingInTheSameRoundPreventsGameOver() {
        let players = [makePlayer(id: "p1", hp: 0), makePlayer(id: "p2", hp: 2)]

        let resolution = resolve(
            [makeResult("P1", hpChange: 4), makeResult("P2", hpChange: -2)],
            players: players
        )

        XCTAssertFalse(resolution.isPartyDown)
    }
}
