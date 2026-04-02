import Foundation

@discardableResult
private func assertEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String
) -> Bool {
    guard actual == expected else {
        fputs("Assertion failed: \(message)\nExpected: \(expected)\nActual: \(actual)\n", stderr)
        exit(1)
    }

    return true
}

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

private func testLastUsedConfigurationRoundTrip() throws {
    AIHostConfigurationStore.clearLastUsed()

    let configuration = makeConfiguration(model: "gpt-4.1")
    try AIHostConfigurationStore.saveLastUsed(configuration)

    let loaded = try AIHostConfigurationStore.loadLastUsed()
    assertEqual(loaded, configuration, "最後一次使用的 AI 設定應該可以完整讀回")
}

private func testCampaignConfigurationRemainsIndependent() throws {
    AIHostConfigurationStore.clearLastUsed()

    let campaignConfiguration = makeConfiguration(model: "gpt-4o-mini")
    let lastUsedConfiguration = makeConfiguration(model: "deepseek-chat")

    try AIHostConfigurationStore.save(campaignConfiguration, campaignId: "campaign-A")
    try AIHostConfigurationStore.saveLastUsed(lastUsedConfiguration)

    let loadedCampaignConfiguration = try AIHostConfigurationStore.load(campaignId: "campaign-A")
    let loadedLastUsedConfiguration = try AIHostConfigurationStore.loadLastUsed()

    assertEqual(loadedCampaignConfiguration, campaignConfiguration, "房間專屬設定不該被最後一次使用的設定覆蓋")
    assertEqual(loadedLastUsedConfiguration, lastUsedConfiguration, "最後一次使用的設定應該獨立保存")
}

@main
struct AIHostConfigurationStoreManualTestsRunner {
    static func main() {
        do {
            try testLastUsedConfigurationRoundTrip()
            try testCampaignConfigurationRemainsIndependent()
            print("AIHostConfigurationStore manual tests passed")
        } catch {
            fputs("Test execution failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
