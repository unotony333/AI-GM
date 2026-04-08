//
//  AIHostConfigurationStoreTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class AIHostConfigurationStoreTests: XCTestCase {

    private func makeConfiguration(model: String = "gpt-4.1-mini") -> AIHostConfiguration {
        AIHostConfiguration(
            provider: "OpenAI",
            apiFormat: .openAICompatible,
            baseURL: "https://api.openai.com/v1",
            model: model,
            apiKey: "secret",
            systemPrompt: "你是一個TRPG GM。"
        )
    }

    override func tearDown() {
        super.tearDown()
        AIHostConfigurationStore.clearLastUsed()
    }

    func testLastUsedConfigurationRoundTrip() throws {
        let configuration = makeConfiguration(model: "gpt-4.1")
        try AIHostConfigurationStore.saveLastUsed(configuration)

        let loaded = try AIHostConfigurationStore.loadLastUsed()
        XCTAssertEqual(loaded, configuration, "最後一次使用的 AI 設定應該可以完整讀回")
    }

    func testCampaignConfigurationRemainsIndependent() throws {
        let campaignConfiguration = makeConfiguration(model: "gpt-4o-mini")
        let lastUsedConfiguration = makeConfiguration(model: "deepseek-chat")

        try AIHostConfigurationStore.save(campaignConfiguration, campaignId: "campaign-A")
        try AIHostConfigurationStore.saveLastUsed(lastUsedConfiguration)

        let loadedCampaignConfiguration = try AIHostConfigurationStore.load(campaignId: "campaign-A")
        let loadedLastUsedConfiguration = try AIHostConfigurationStore.loadLastUsed()

        XCTAssertEqual(loadedCampaignConfiguration, campaignConfiguration, "房間專屬設定不該被最後一次使用的設定覆蓋")
        XCTAssertEqual(loadedLastUsedConfiguration, lastUsedConfiguration, "最後一次使用的設定應該獨立保存")
    }
}
