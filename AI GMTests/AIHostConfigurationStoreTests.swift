//
//  AIHostConfigurationStoreTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class AIHostConfigurationStoreTests: XCTestCase {

    // 測試用獨立的儲存區，不能動到 App 真正保存的 AI 設定與 API Key
    private static let suiteName = "AIHostConfigurationStoreTests"
    private static let keychainService = "com.aigm.apikeys.tests"

    private var storage: AIHostConfigurationStore.Storage!

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

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        defaults.removePersistentDomain(forName: Self.suiteName)
        storage = AIHostConfigurationStore.Storage(defaults: defaults, keychainService: Self.keychainService)
    }

    override func tearDown() {
        AIHostConfigurationStore.clearLastUsed(storage: storage)
        AIHostConfigurationStore.clear(campaignId: "campaign-A", storage: storage)
        storage.defaults.removePersistentDomain(forName: Self.suiteName)
        storage = nil
        super.tearDown()
    }

    func testLastUsedConfigurationRoundTrip() throws {
        let configuration = makeConfiguration(model: "gpt-4.1")
        try AIHostConfigurationStore.saveLastUsed(configuration, storage: storage)

        let loaded = try AIHostConfigurationStore.loadLastUsed(storage: storage)
        XCTAssertEqual(loaded, configuration, "最後一次使用的 AI 設定應該可以完整讀回")
    }

    func testCampaignConfigurationRemainsIndependent() throws {
        let campaignConfiguration = makeConfiguration(model: "gpt-4o-mini")
        let lastUsedConfiguration = makeConfiguration(model: "deepseek-chat")

        try AIHostConfigurationStore.save(campaignConfiguration, campaignId: "campaign-A", storage: storage)
        try AIHostConfigurationStore.saveLastUsed(lastUsedConfiguration, storage: storage)

        let loadedCampaignConfiguration = try AIHostConfigurationStore.load(campaignId: "campaign-A", storage: storage)
        let loadedLastUsedConfiguration = try AIHostConfigurationStore.loadLastUsed(storage: storage)

        XCTAssertEqual(loadedCampaignConfiguration, campaignConfiguration, "房間專屬設定不該被最後一次使用的設定覆蓋")
        XCTAssertEqual(loadedLastUsedConfiguration, lastUsedConfiguration, "最後一次使用的設定應該獨立保存")
    }

    func testTestStorageLeavesAppStorageUntouched() throws {
        // 直接讀 App 的原始資料（不經過 Store，避免觸發舊格式遷移而改寫資料）
        let appConfigKey = "hostAIConfig.lastUsed"
        let appApiKeyKey = "aiApiKey.lastUsed"
        let appConfigBefore = UserDefaults.standard.data(forKey: appConfigKey)
        let appApiKeyBefore = KeychainService.load(key: appApiKeyKey)

        try AIHostConfigurationStore.saveLastUsed(makeConfiguration(), storage: storage)
        AIHostConfigurationStore.clearLastUsed(storage: storage)

        XCTAssertEqual(UserDefaults.standard.data(forKey: appConfigKey), appConfigBefore, "測試不該改動 App 的 AI 設定")
        XCTAssertEqual(KeychainService.load(key: appApiKeyKey), appApiKeyBefore, "測試不該改動 App 的 API Key")
    }
}
